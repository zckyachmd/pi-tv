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
    private var queue = PeerQueue(limit: 16)
    private var subscriber: CBCentral?

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            status = "Bluetooth unavailable: \(peripheral.state.rawValue)"
            queue.reset()
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
        guard characteristic.uuid == txID else { return }
        guard queue.subscribe(central.identifier) else { log("Additional subscriber ignored"); return }
        subscriber = central
        log("Subscribed; maximum notification: \(central.maximumUpdateValueLength) bytes")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == txID, subscriber?.identifier == central.identifier else { return }
        queue.unsubscribe(central.identifier)
        subscriber = nil
        log("Unsubscribed; pending notifications cleared")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let writes = requests.map { request in
            PeerQueue.Write(peer: request.central.identifier,
                            valid: request.characteristic.uuid == rxID && request.offset == 0 && (request.value?.count ?? 129) <= min(128, subscriber?.maximumUpdateValueLength ?? 0),
                            data: request.value)
        }
        let decision = queue.admit(writes)
        guard let first = requests.first else { return }
        let result: CBATTError.Code
        switch decision {
        case .success: result = .success
        case .peer: result = .unlikelyError
        case .invalid: result = .invalidAttributeValueLength
        case .full: result = .insufficientResources
        case .empty: return
        }
        peripheral.respond(to: first, withResult: result)
        if decision == .success { flush() }
    }

    private func flush() {
        guard let tx, let subscriber else { return }
        while let data = queue.pending.first {
            guard manager.updateValue(data, for: tx, onSubscribedCentrals: [subscriber]) else { log("Notification backpressure; queued \(queue.pending.count)"); return }
            queue.delivered()
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
