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
    private var requests = Requests()
    private var transport = RecordTransport()
    private var writeOutstanding = false
    @Published var payloadSize = 64
    private var peerID: String { peripheral?.identifier.uuidString ?? "" }
    private var milliseconds: UInt64 { UInt64(ProcessInfo.processInfo.systemUptime * 1000) }
    @Published var requestStatus = "No request"
    private var timer: Timer?
    private func transition(_ state: Lifecycle.State, timeout: TimeInterval? = nil) -> Bool {
        guard lifecycle.move(state, timeout: timeout) else { return false }
        status = state.rawValue; ready = state == .ready; return true
    }
    private func fail(_ reason: String) {
        requests.clear(); updateRequest()
        status = reason
        guard let peripheral else { _ = transition(.failed); status = reason; return }
        guard lifecycle.state != .disconnecting && lifecycle.state != .failed else { return }
        lifecycle.invalidate(); ready = false
        status = reason + "; disconnecting"
        manager.cancelPeripheralConnection(peripheral)
    }
    private func checkDeadlines() {
        if lifecycle.state == .ready {
            do { try transport.expire(peerID, now: milliseconds) }
            catch { fail("Fragment expiry: \(error)"); return }
        }
        if lifecycle.expired() {
            if lifecycle.state == .disconnecting {
                lifecycle.expireDisconnect(); ready = false; status = "Disconnect confirmation timed out; recovery required"
            } else { fail("Transport timeout: \(lifecycle.state.rawValue)") }
            return
        }
        if let outcome = requests.update({ $0.expire(ProcessInfo.processInfo.systemUptime) }) {
            updateRequest()
            if outcome == .acknowledgementTimeout || outcome == .echoTimeout { fail(outcome.rawValue) }
        }
    }
    private func active(_ candidate: CBPeripheral, _ state: Lifecycle.State) -> Bool {
        peripheral === candidate && lifecycle.state == state
    }
    override init() { super.init(); manager = CBCentralManager(delegate: self, queue: .main); timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkDeadlines() } }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard lifecycle.state != .failed else { return }
        guard central.state == .poweredOn else { requests.clear(); clear(); _ = transition(.unavailable); return }
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
        guard active(peripheral, .connecting) else { return }; clear(); _ = transition(.disconnected); status = "Connection failed"
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }; requests.clear(); updateRequest(); clear(); _ = transition(.disconnected)
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
        guard self.peripheral === peripheral, characteristic.uuid == txID else { return }
        if lifecycle.state == .ready {
            if error != nil || !characteristic.isNotifying { fail("Subscription lost") }
            return
        }
        guard lifecycle.state == .subscribing else { return }
        guard error == nil, characteristic.isNotifying else { fail("Subscription failed"); return }
        _ = transition(.ready)
    }
    func send() {
        guard lifecycle.canSend, requests.active == nil, let peripheral, let rx, sequence < .max else { return }
        sequence += 1
        let data = Data((0..<payloadSize).map { UInt8(truncatingIfNeeded: $0 + Int(sequence % 256)) })
        let now = ProcessInfo.processInfo.systemUptime
        guard requests.admit(EchoRequest(id: sequence, generation: lifecycle.generation, payload: data, sent: now, deadline: now + 30), ready: lifecycle.canSend) else { return }
        do {
            try transport.sender.start(Array(data), capacity: min(512, peripheral.maximumWriteValueLength(for: .withResponse)))
            requestStatus = "Sending fragments"
            sendNext(peripheral, rx)
        } catch { fail("Cannot start request: \(error)") }
    }
    private func sendNext(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) {
        guard !writeOutstanding, let frame = transport.sender.frame() else { return }
        writeOutstanding = true
        peripheral.writeValue(Data(frame), for: characteristic, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .ready), characteristic.uuid == rxID else { return }
        guard writeOutstanding, requests.active?.generation == lifecycle.generation else { fail("Ambiguous write acknowledgement"); return }
        writeOutstanding = false
        guard error == nil else { _ = requests.update { $0.ack(error: true) }; updateRequest(); fail("Write failed"); return }
        do { try transport.sender.advance() } catch { fail("Invalid write state"); return }
        if transport.sender.busy { sendNext(peripheral, characteristic) }
        else { _ = requests.update { $0.ack(error: false) }; updateRequest() }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .ready), characteristic.uuid == txID else { return }
        guard error == nil, let data = characteristic.value, requests.active?.generation == lifecycle.generation else { fail("Unexpected or failed notification"); return }
        do {
            guard let record = try transport.receive(peerID, Array(data), capacity: 512, now: milliseconds) else { return }
            var message = "stale response"
            let outcome = requests.update { message = $0.echo(Data(record), at: ProcessInfo.processInfo.systemUptime) }
            log(message); updateRequest()
            if outcome == .mismatch { fail("Payload mismatch") }
        } catch { fail("Invalid notification: \(error)") }
    }

    private func updateRequest() {
        guard let request = requests.active ?? requests.last else { return }
        requestStatus = request.outcome?.rawValue ?? "Waiting"
        if request.outcome == .success, let echo = request.echoAt { requestStatus += String(format: " RTT %.2f ms", (echo - request.sent) * 1000) }
    }

    func disconnect() {
        manager.stopScan()
        requests.clear(); updateRequest()
        if let peripheral { guard lifecycle.state != .failed else { return }; _ = transition(.disconnecting, timeout: 10); manager.cancelPeripheralConnection(peripheral) } else { clear(); _ = transition(.disconnected) }
    }
    private func clear() { requests.clear(); transport = RecordTransport(); writeOutstanding = false; ready = false; rx = nil; peripheral = nil }
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
                    Picker("Payload", selection: $central.payloadSize) {
                        ForEach([64, 256, 1024, 4096], id: \.self) { Text("\($0) bytes").tag($0) }
                    }
                    Button("Send test", action: central.send).disabled(!central.ready)
                }
                ScrollView { Text(central.events).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            }.padding()
        }
    }
}
