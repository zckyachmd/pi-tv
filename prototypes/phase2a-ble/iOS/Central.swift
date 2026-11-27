import SwiftUI
import CoreBluetooth

private let serviceID = CBUUID(string: "5B5D0001-A82D-46F2-8DF0-15127B196240")
private let rxID = CBUUID(string: "5B5D0002-A82D-46F2-8DF0-15127B196240")
private let txID = CBUUID(string: "5B5D0003-A82D-46F2-8DF0-15127B196240")

final class Central: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Starting Bluetooth"
    @Published var events = ""
    @Published var ready = false
    private var manager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var sequence: UInt64 = 0
    private var lifecycle = Lifecycle()
    private var request: EchoRequest?
    @Published var requestStatus = "No request"
    private var timer: Timer?
    private func transition(_ state: Lifecycle.State, timeout: TimeInterval? = nil) -> Bool {
        guard lifecycle.move(state, timeout: timeout) else { return false }
        status = state.rawValue; ready = state == .ready; return true
    }
    private func fail(_ reason: String) {
        request?.cancel(); updateRequest()
        status = reason
        guard let peripheral else { _ = transition(.failed); status = reason; return }
        guard lifecycle.state != .disconnecting && lifecycle.state != .failed else { return }
        lifecycle.invalidate(); ready = false
        status = reason + "; disconnecting"
        manager.cancelPeripheralConnection(peripheral)
    }
    private func checkDeadlines() {
        if lifecycle.expired() {
            if lifecycle.state == .disconnecting {
                lifecycle.expireDisconnect(); ready = false; status = "Disconnect confirmation timed out; recovery required"
            } else { fail("Transport timeout: \(lifecycle.state.rawValue)") }
            return
        }
        request?.expire(ProcessInfo.processInfo.systemUptime)
        if let outcome = request?.outcome, outcome == .acknowledgementTimeout || outcome == .echoTimeout { fail(outcome.rawValue) }
    }
    private func active(_ candidate: CBPeripheral, _ state: Lifecycle.State) -> Bool {
        peripheral === candidate && lifecycle.state == state
    }
    override init() { super.init(); manager = CBCentralManager(delegate: self, queue: .main); timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkDeadlines() } }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard lifecycle.state != .failed else { return }
        guard central.state == .poweredOn else { request?.cancel(); clear(); _ = transition(.unavailable); return }
        _ = transition(.idle); scan()
    }
    func scan() {
        guard manager.state == .poweredOn else { return }
        guard peripheral == nil else { log("Disconnect before scanning again"); return }
        manager.stopScan()
        clear(); guard transition(.scanning) else { return }
        manager.scanForPeripherals(withServices: [serviceID])
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard lifecycle.state == .scanning, transition(.connecting, timeout: 15) else { return }
        central.stopScan(); self.peripheral = peripheral; peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard active(peripheral, .connecting), transition(.services, timeout: 10) else { return }
        log("Connected; maximum write with response: \(peripheral.maximumWriteValueLength(for: .withResponse)) bytes")
        peripheral.discoverServices([serviceID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard active(peripheral, .connecting) else { return }; fail("Connection failed")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }; request?.cancel(); requestStatus = request?.outcome?.rawValue ?? "Disconnected"; clear(); _ = transition(.disconnected)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard active(peripheral, .services) else { return }
        if error != nil { fail("Service discovery failed"); return }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else { fail("Service missing"); return }
        guard transition(.characteristics, timeout: 10) else { return }; peripheral.discoverCharacteristics([rxID, txID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard active(peripheral, .characteristics), service.uuid == serviceID else { return }
        if error != nil { fail("Characteristic discovery failed"); return }
        rx = service.characteristics?.first(where: { $0.uuid == rxID })
        guard rx != nil, let tx = service.characteristics?.first(where: { $0.uuid == txID }) else { fail("Characteristic missing"); return }
        guard transition(.subscribing, timeout: 10) else { return }; peripheral.setNotifyValue(true, for: tx)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard active(peripheral, .subscribing), characteristic.uuid == txID else { return }
        guard error == nil, characteristic.isNotifying else { fail("Subscription failed"); return }
        _ = transition(.ready)
    }
    func send() {
        guard lifecycle.canSend, request == nil || request?.outcome == .success, let peripheral, let rx, sequence < .max else { return }
        sequence += 1
        let data = Data("echo \(sequence)".utf8)
        guard data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        request = EchoRequest(id: sequence, generation: lifecycle.generation, payload: data, sent: now, deadline: now + 10)
        requestStatus = "Waiting for acknowledgement and echo"
        peripheral.writeValue(data, for: rx, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .ready), characteristic.uuid == rxID, request?.generation == lifecycle.generation else { return }
        request?.ack(error: error != nil)
        updateRequest()
        if error != nil { fail("Write failed") }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .ready), characteristic.uuid == txID, error == nil, let data = characteristic.value, request?.generation == lifecycle.generation else { return }
        let message = request?.echo(data, at: ProcessInfo.processInfo.systemUptime) ?? "stale response"
        log(message); updateRequest()
        if request?.outcome == .mismatch { fail("Payload mismatch") }
    }
    private func updateRequest() {
        guard let request else { return }
        requestStatus = request.outcome?.rawValue ?? "Waiting"
        if request.outcome == .success, let echo = request.echoAt { requestStatus += String(format: " RTT %.2f ms", (echo - request.sent) * 1000) }
    }

    func disconnect() {
        manager.stopScan()
        request?.cancel(); updateRequest()
        if let peripheral { guard lifecycle.state != .failed else { return }; _ = transition(.disconnecting, timeout: 10); manager.cancelPeripheralConnection(peripheral) } else { clear(); _ = transition(.disconnected) }
    }
    private func clear() { ready = false; rx = nil; peripheral = nil }
}

@main struct CentralApp: App {
    @StateObject private var central = Central()
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Phase 2A central").font(.title)
                Text(central.status)
                Text(central.requestStatus)
                HStack {
                    Button("Scan", action: central.scan)
                    Button("Disconnect", action: central.disconnect)
                    Button("Send test", action: central.send).disabled(!central.ready)
                }
                ScrollView { Text(central.events).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            }.padding()
        }
    }
}
