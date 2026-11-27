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
    @Published var attemptCount = 100
    @Published var delayMilliseconds = 0
    @Published var benchmarkStatus = "No benchmark"
    @Published var exportURL: URL?
    @Published var benchmarkRunning = false
    private var benchmarkResults: [BenchmarkAttempt] = []
    private var benchmarkAttempt: BenchmarkAttempt?
    private var benchmarkRemaining = 0
    private var benchmarkToken = 0
    private var benchmarkFile: URL?
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
        finishBenchmarkAttempt(reason: reason)
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
        guard central.state == .poweredOn else { requests.clear(); finishBenchmarkAttempt(reason: "Bluetooth unavailable"); clear(); _ = transition(.unavailable); return }
        _ = transition(.idle); scan()
    }
    func scan() {
        guard manager.state == .poweredOn else { return }
        guard peripheral == nil else { log("Disconnect before scanning again"); return }
        guard lifecycle.state != .scanning else { return }
        guard transition(.scanning) else { return }
        clear()
        manager.scanForPeripherals(withServices: [serviceID])
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard lifecycle.state == .scanning, transition(.connecting, timeout: 15) else { return }
        central.stopScan(); self.peripheral = peripheral; peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        checkDeadlines()
        guard active(peripheral, .connecting), transition(.services, timeout: 10) else { return }
        log("Connected; maximum write with response: \(peripheral.maximumWriteValueLength(for: .withResponse)) bytes")
        peripheral.discoverServices([serviceID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .connecting) else { return }; clear(); _ = transition(.disconnected); status = "Connection failed"
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }; requests.clear(); updateRequest(); finishBenchmarkAttempt(reason: "Disconnected"); clear(); _ = transition(.disconnected)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        checkDeadlines()
        guard active(peripheral, .services) else { return }
        if error != nil { fail("Service discovery failed"); return }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else { fail("Service missing"); return }
        guard transition(.characteristics, timeout: 10) else { return }; peripheral.discoverCharacteristics([rxID, txID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .characteristics), service.uuid == serviceID else { return }
        if error != nil { fail("Characteristic discovery failed"); return }
        rx = service.characteristics?.first(where: { $0.uuid == rxID })
        guard rx != nil, let tx = service.characteristics?.first(where: { $0.uuid == txID }) else { fail("Characteristic missing"); return }
        guard transition(.subscribing, timeout: 10) else { return }; peripheral.setNotifyValue(true, for: tx)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
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
        let data = syntheticPayload(size: payloadSize, id: sequence)
        let now = ProcessInfo.processInfo.systemUptime
        guard requests.admit(EchoRequest(id: sequence, generation: lifecycle.generation, payload: data, sent: now, deadline: now + 30), ready: lifecycle.canSend) else { return }
        if benchmarkRunning {
            benchmarkAttempt = BenchmarkAttempt(requestID: sequence, generation: lifecycle.generation, payloadSize: data.count, startedAt: now, writeCapacity: peripheral.maximumWriteValueLength(for: .withResponse))
            exportResults()
        }
        do {
            try transport.sender.start(Array(data), capacity: min(512, peripheral.maximumWriteValueLength(for: .withResponse)))
            requestStatus = "Sending fragments"
            sendNext(peripheral, rx)
        } catch { fail("Cannot start request: \(error)") }
    }
    private func sendNext(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) {
        guard !writeOutstanding, let frame = transport.sender.frame() else { return }
        writeOutstanding = true
        benchmarkAttempt?.writeFrameSizes.append(frame.count)
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
        else { benchmarkAttempt?.finalWriteAcknowledgedAt = ProcessInfo.processInfo.systemUptime; _ = requests.update { $0.ack(error: false) }; updateRequest(); completeBenchmarkIfSuccessful() }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        checkDeadlines()
        guard active(peripheral, .ready), characteristic.uuid == txID else { return }
        guard error == nil, let data = characteristic.value, requests.active?.generation == lifecycle.generation else { fail("Unexpected or failed notification"); return }
        benchmarkAttempt?.notificationFrameSizes.append(data.count)
        do {
            guard let record = try transport.receive(peerID, Array(data), capacity: 512, now: milliseconds) else { return }
            var message = "stale response"
            let outcome = requests.update { message = $0.echo(Data(record), at: ProcessInfo.processInfo.systemUptime) }
            if message == "matching echo" { benchmarkAttempt?.echoAt = ProcessInfo.processInfo.systemUptime }
            log(message); updateRequest()
            if outcome == .mismatch { fail("Payload mismatch") }
            else { completeBenchmarkIfSuccessful() }
        } catch { fail("Invalid notification: \(error)") }
    }

    private func updateRequest() {
        guard let request = requests.active ?? requests.last else { return }
        requestStatus = request.outcome?.rawValue ?? "Waiting"
        if request.outcome == .success, let echo = request.echoAt { requestStatus += String(format: " RTT %.2f ms", (echo - request.sent) * 1000) }
    }

    func disconnect() {
        if benchmarkRunning { cancelBenchmark() }
        manager.stopScan()
        requests.clear(); updateRequest()
        if let peripheral { guard lifecycle.state != .failed else { return }; _ = transition(.disconnecting, timeout: 10); manager.cancelPeripheralConnection(peripheral) } else { clear(); _ = transition(.disconnected) }
    }
    private func clear() { requests.clear(); transport = RecordTransport(); writeOutstanding = false; ready = false; rx = nil; peripheral = nil }

    func runBenchmark() {
        guard ready, requests.active == nil, !benchmarkRunning, (1...1000).contains(attemptCount), (0...10000).contains(delayMilliseconds) else { return }
        benchmarkToken += 1; benchmarkResults = []; benchmarkRemaining = attemptCount; benchmarkRunning = true
        benchmarkFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("phase2a-\(UUID().uuidString).json")
        exportURL = nil; benchmarkStatus = "Running"; send()
        if benchmarkAttempt == nil { finishBenchmarkAttempt(reason: "Request could not start") }
    }
    func cancelBenchmark() {
        guard benchmarkRunning else { return }
        benchmarkToken += 1
        if benchmarkAttempt != nil { fail("Benchmark cancelled") }
        else { benchmarkRunning = false; benchmarkStatus = "Cancelled"; exportResults() }
    }
    private func completeBenchmarkIfSuccessful() {
        guard benchmarkRunning, let attempt = benchmarkAttempt, requests.last?.id == attempt.requestID, requests.last?.outcome == .success else { return }
        finishBenchmarkAttempt(reason: nil)
        guard benchmarkRunning else { return }
        let token = benchmarkToken
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMilliseconds)) { [weak self] in
            guard let self, self.benchmarkRunning, self.benchmarkToken == token else { return }
            self.send()
            if self.benchmarkAttempt == nil { self.finishBenchmarkAttempt(reason: "Request could not start") }
        }
    }
    private func finishBenchmarkAttempt(reason: String?) {
        guard benchmarkRunning else { return }
        if var attempt = benchmarkAttempt {
            attempt.endedAt = ProcessInfo.processInfo.systemUptime
            let requestOutcome = requests.last?.outcome
            attempt.outcome = reason == nil ? "success" : (reason == "Benchmark cancelled" ? "cancelled" : (requestOutcome == .cancelled ? "failed" : requestOutcome?.rawValue ?? "failed"))
            attempt.failureReason = reason
            benchmarkResults.append(attempt); benchmarkAttempt = nil; benchmarkRemaining -= 1
        }
        if reason != nil || benchmarkRemaining == 0 {
            benchmarkRunning = false
            benchmarkStatus = reason.map { "Stopped: \($0)" } ?? "Completed"
        } else { benchmarkStatus = "Completed \(benchmarkResults.count) of \(attemptCount)" }
        exportResults()
    }
    private func exportResults() {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let url = benchmarkFile else { return }
            let report = BenchmarkReport(requestedAttempts: attemptCount, delayMilliseconds: delayMilliseconds, status: benchmarkStatus, attempts: benchmarkResults + (benchmarkAttempt.map { [$0] } ?? []))
            try encoder.encode(report).write(to: url, options: .atomic); exportURL = url
        } catch { benchmarkStatus += "; export failed: \(error.localizedDescription)" }
    }
}

@main struct CentralApp: App {
    @StateObject private var central = Central()
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Phase 2A central").font(.title)
                Text(central.status)
                Text(central.requestStatus)
                Text(central.benchmarkStatus)
                HStack {
                    Stepper("Attempts: \(central.attemptCount)", value: $central.attemptCount, in: 1...1000)
                    Stepper("Delay: \(central.delayMilliseconds) ms", value: $central.delayMilliseconds, in: 0...10000, step: 100)
                }.disabled(central.benchmarkRunning)
                HStack {
                    Button("Run Benchmark", action: central.runBenchmark).disabled(!central.ready || central.benchmarkRunning)
                    Button("Cancel benchmark", action: central.cancelBenchmark).disabled(!central.benchmarkRunning)
                    if let url = central.exportURL { ShareLink("Export results", item: url) }
                }
                HStack {
                    Button("Scan", action: central.scan)
                    Button("Disconnect", action: central.disconnect)
                    Picker("Payload", selection: $central.payloadSize) {
                        ForEach([64, 256, 1024, 4096], id: \.self) { Text("\($0) bytes").tag($0) }
                    }.disabled(central.benchmarkRunning)
                    Button("Send test", action: central.send).disabled(!central.ready || central.benchmarkRunning)
                }
                ScrollView { Text(central.events).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            }.padding()
        }
    }
}
