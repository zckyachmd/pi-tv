import SwiftUI
import CoreBluetooth

private let serviceID = CBUUID(string: "5B5D0001-A82D-46F2-8DF0-15127B196240")
private let rxID = CBUUID(string: "5B5D0002-A82D-46F2-8DF0-15127B196240")
private let txID = CBUUID(string: "5B5D0003-A82D-46F2-8DF0-15127B196240")

final class Peripheral: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published var status = "Starting Bluetooth"
    @Published var events = ""
    private var manager: CBPeripheralManager!
    private var tx: CBMutableCharacteristic?
    private var pending: [Data] = []
    private let queueLimit = 16
    private var subscriber: CBCentral?

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            status = "Bluetooth unavailable: \(peripheral.state.rawValue)"
            pending.removeAll()
            tx = nil
            subscriber = nil
            return
        }
        let rx = CBMutableCharacteristic(type: rxID, properties: [.write], value: nil, permissions: [.writeable])
        let tx = CBMutableCharacteristic(type: txID, properties: [.notify], value: nil, permissions: [])
        self.tx = tx
        let service = CBMutableService(type: serviceID, primary: true)
        service.characteristics = [rx, tx]
        peripheral.removeAllServices()
        peripheral.add(service)
        status = "Registering service"
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { status = "Service error: \(error.localizedDescription)"; return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceID], CBAdvertisementDataLocalNameKey: "Phase2A Echo"])
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        status = error.map { "Advertising error: \($0.localizedDescription)" } ?? "Advertising"
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        subscriber = central
        log("Subscribed; maximum notification: \(central.maximumUpdateValueLength) bytes")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscriber = nil
        pending.removeAll()
        log("Unsubscribed; pending notifications cleared")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == rxID, request.offset == 0, let data = request.value, data.count <= 128 else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength); continue
            }
            guard let subscriber, data.count <= subscriber.maximumUpdateValueLength else {
                peripheral.respond(to: request, withResult: .unlikelyError)
                log("No subscriber or payload exceeds notification limit"); continue
            }
            guard pending.count < queueLimit else {
                peripheral.respond(to: request, withResult: .insufficientResources)
                log("Notification queue full"); continue
            }
            pending.append(data)
            peripheral.respond(to: request, withResult: .success)
            log("Received \(String(decoding: data, as: UTF8.self)); queued \(pending.count)")
            flush()
        }
    }
    private func flush() {
        guard let tx else { return }
        while let data = pending.first {
            guard manager.updateValue(data, for: tx, onSubscribedCentrals: subscriber.map { [$0] }) else { log("Notification backpressure; queued \(pending.count)"); return }
            pending.removeFirst()
        }
    }
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) { flush() }
}

@main struct PeripheralApp: App {
    @StateObject private var peripheral = Peripheral()
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading) {
                Text("Phase 2A peripheral").font(.title)
                Text(peripheral.status)
                ScrollView { Text(peripheral.events).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding().frame(minWidth: 480, minHeight: 300)
        }
    }
}
