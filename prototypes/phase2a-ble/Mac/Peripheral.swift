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
    private var transport = RecordTransport()
    private var timer: Timer?
    private var outboundDeadline: UInt64?
    private var milliseconds: UInt64 { UInt64(ProcessInfo.processInfo.systemUptime * 1000) }
    private func resetTransport() { transport = RecordTransport(); outboundDeadline = nil }
    private func expire() {
        guard let subscriber else { return }
        if let deadline = outboundDeadline, milliseconds >= deadline {
            transport.invalidate(); outboundDeadline = nil; log("Outbound notification timed out"); return
        }
        do { try transport.expire(subscriber.identifier.uuidString, now: milliseconds) }
        catch { log("Transport expired: \(error)") }
    }

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.expire() }
    }
    private func log(_ message: String) { events = message + "\n" + String(events.prefix(4000)) }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            status = "Bluetooth unavailable: \(peripheral.state.rawValue)"
            queue.reset()
            resetTransport()
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
        if subscriber == nil { resetTransport() }
        subscriber = central
        log("Subscribed; maximum notification: \(central.maximumUpdateValueLength) bytes")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == txID, subscriber?.identifier == central.identifier else { return }
        queue.unsubscribe(central.identifier)
        resetTransport()
        subscriber = nil
        log("Unsubscribed; pending notifications cleared")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        let writes = requests.map { request in
            PeerQueue.Write(peer: request.central.identifier,
                            valid: requests.count == 1 && request.characteristic.uuid == rxID && request.offset == 0 && request.value != nil && (request.value?.count ?? 513) <= 512,
                            data: request.value)
        }
        let decision = queue.admit(writes)
        guard decision == .success else {
            if first.central.identifier == subscriber?.identifier { transport.invalidate() }
            let result: CBATTError.Code = decision == .full ? .insufficientResources : .unlikelyError
            peripheral.respond(to: first, withResult: result); return
        }
        defer { queue.delivered() }
        guard let subscriber, !transport.failed, !transport.sender.busy, let data = first.value else {
            transport.invalidate(); peripheral.respond(to: first, withResult: .insufficientResources); return
        }
        do {
            let record = try transport.receive(subscriber.identifier.uuidString, Array(data), capacity: 512, now: milliseconds)
            if let record { try transport.sender.start(record, capacity: min(512, subscriber.maximumUpdateValueLength)); outboundDeadline = milliseconds + 30000 }
            peripheral.respond(to: first, withResult: .success)
            if record != nil { flush() }
        } catch {
            transport.invalidate()
            peripheral.respond(to: first, withResult: .unlikelyError)
            log("Transport failed: \(error)")
        }
    }

    private func flush() {
        guard let tx, let subscriber, !transport.failed else { return }
        while let frame = transport.sender.frame() {
            let accepted = manager.updateValue(Data(frame), for: tx, onSubscribedCentrals: [subscriber])
            do { try transport.sender.notificationResult(accepted) } catch { transport.invalidate(); log("Notification state failed"); return }
            guard accepted else { log("Notification backpressure"); return }
            outboundDeadline = transport.sender.busy ? milliseconds + 30000 : nil
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
