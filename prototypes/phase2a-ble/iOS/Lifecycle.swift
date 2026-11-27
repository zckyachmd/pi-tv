import Foundation

struct Lifecycle {
    enum State: String { case unavailable, idle, scanning, connecting, services, characteristics, subscribing, ready, disconnecting, disconnected, failed }
    private(set) var state: State = .unavailable
    private(set) var generation: UInt64 = 0
    private(set) var deadline: TimeInterval?
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    mutating func move(_ next: State, timeout: TimeInterval? = nil) -> Bool {
        if expired() && ![State.unavailable, .failed, .disconnected, .disconnecting].contains(next) { return false }
        let allowed: Bool
        switch (state, next) {
        case (_, .unavailable), (_, .failed), (_, .disconnected), (_, .disconnecting): allowed = true
        case (.unavailable, .idle), (.disconnected, .scanning), (.idle, .scanning), (.scanning, .connecting), (.connecting, .services), (.services, .characteristics), (.characteristics, .subscribing), (.subscribing, .ready): allowed = true
        default: allowed = false
        }
        guard allowed else { return false }
        if next == .connecting { guard generation < .max else { return false }; generation += 1 }
        state = next; deadline = timeout.map { now() + $0 }; return true
    }
    mutating func invalidate() { _ = move(.disconnecting, timeout: 10) }
    mutating func expireDisconnect() {
        if state == .disconnecting && expired() { _ = move(.failed) }
    }
    var canSend: Bool { state == .ready }
    func expired() -> Bool { deadline.map { now() >= $0 } ?? false }
}

func syntheticPayload(size: Int, id: UInt64) -> Data {
    precondition(size >= 8)
    var data = Data((0..<size).map { UInt8(truncatingIfNeeded: $0) })
    for index in 0..<8 { data[index] = UInt8(truncatingIfNeeded: id >> ((7 - index) * 8)) }
    return data
}

struct BenchmarkAttempt: Codable {
    let requestID: UInt64, generation: UInt64, payloadSize: Int
    let startedAt: TimeInterval, writeCapacity: Int
    var writeFrameSizes: [Int] = [], notificationFrameSizes: [Int] = []
    var finalWriteAcknowledgedAt: TimeInterval?, echoAt: TimeInterval?, endedAt: TimeInterval?
    var outcome: String?, failureReason: String?
}

struct BenchmarkReport: Codable {
    let requestedAttempts: Int, delayMilliseconds: Int
    let status: String
    let attempts: [BenchmarkAttempt]
}

struct EchoRequest {
    enum Outcome: String { case success, writeFailure, acknowledgementTimeout, echoTimeout, mismatch, cancelled }
    let id: UInt64
    let generation: UInt64
    let payload: Data
    let sent: TimeInterval
    let deadline: TimeInterval
    var acknowledged = false
    var echoAt: TimeInterval?
    var outcome: Outcome?
    mutating func ack(error: Bool) {
        guard outcome == nil else { return }
        if error { outcome = .writeFailure } else { acknowledged = true; complete() }
    }
    mutating func echo(_ data: Data, at now: TimeInterval) -> String {
        guard outcome == nil else { return "late response" }
        guard data == payload else { outcome = .mismatch; return "payload mismatch" }
        guard echoAt == nil else { return "duplicate notification" }
        echoAt = now; complete(); return "matching echo"
    }
    mutating func expire(_ now: TimeInterval) {
        guard outcome == nil, now >= deadline else { return }
        outcome = acknowledged ? .echoTimeout : .acknowledgementTimeout
    }
    mutating func cancel() { if outcome == nil { outcome = .cancelled } }
    private mutating func complete() { if acknowledged && echoAt != nil { outcome = .success } }
}

struct Requests {
    private(set) var active: EchoRequest?
    private(set) var last: EchoRequest?
    mutating func admit(_ request: EchoRequest, ready: Bool) -> Bool {
        guard ready, active == nil else { return false }
        active = request
        return true
    }
    mutating func update(_ body: (inout EchoRequest) -> Void) -> EchoRequest.Outcome? {
        guard var request = active else { return nil }
        body(&request)
        if let outcome = request.outcome { last = request; active = nil; return outcome }
        active = request
        return nil
    }
    mutating func clear() { _ = update { $0.cancel() } }
}
