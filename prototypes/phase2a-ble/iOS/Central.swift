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
    private var sequence = 0
    private var writePending = false
    override init() { super.init(); manager = CBCentralManager(delegate: self, queue: .main) }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { clear(); status = "Bluetooth unavailable: \(central.state.rawValue)"; return }
        scan()
    }
    func scan() {
        guard manager.state == .poweredOn else { return }
        guard peripheral == nil else { log("Disconnect before scanning again"); return }
        manager.stopScan()
        clear(); status = "Scanning"
        manager.scanForPeripherals(withServices: [serviceID])
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan(); self.peripheral = peripheral; peripheral.delegate = self
        status = "Connecting"; central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Discovering service"
        log("Connected; maximum write with response: \(peripheral.maximumWriteValueLength(for: .withResponse)) bytes")
        peripheral.discoverServices([serviceID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        clear(); status = "Connection failed: \(error?.localizedDescription ?? "unknown")"
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        clear(); status = "Disconnected: \(error?.localizedDescription ?? "requested")"
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { status = "Service error: \(error.localizedDescription)"; return }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else { status = "Service missing"; return }
        peripheral.discoverCharacteristics([rxID, txID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { status = "Characteristic error: \(error.localizedDescription)"; return }
        rx = service.characteristics?.first(where: { $0.uuid == rxID })
        guard rx != nil, let tx = service.characteristics?.first(where: { $0.uuid == txID }) else { status = "Characteristic missing"; return }
        status = "Subscribing"; peripheral.setNotifyValue(true, for: tx)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        ready = error == nil && characteristic.isNotifying
        status = error.map { "Subscription error: \($0.localizedDescription)" } ?? (ready ? "Connected and subscribed" : "Notifications stopped")
    }
    func send() {
        guard ready, !writePending, let peripheral, let rx else { return }
        sequence += 1
        let data = Data("echo \(sequence)".utf8)
        guard data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else { log("Payload exceeds write limit"); return }
        writePending = true; peripheral.writeValue(data, for: rx, type: .withResponse)
        log("Sent echo \(sequence)")
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writePending = false
        log(error.map { "Write failed: \($0.localizedDescription)" } ?? "Write acknowledged")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Notification error: \(error.localizedDescription)"); return }
        if let data = characteristic.value { log("Notification: \(String(decoding: data, as: UTF8.self))") }
    }
    func disconnect() {
        manager.stopScan()
        if let peripheral { manager.cancelPeripheralConnection(peripheral) } else { clear(); status = "Stopped" }
    }
    private func clear() { ready = false; writePending = false; rx = nil; peripheral = nil }
}

@main struct CentralApp: App {
    @StateObject private var central = Central()
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Phase 2A central").font(.title)
                Text(central.status)
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
