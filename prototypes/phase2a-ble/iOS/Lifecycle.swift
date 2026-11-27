import Foundation

struct Lifecycle {
    enum State: String { case unavailable, idle, scanning, connecting, services, characteristics, subscribing, ready, disconnecting, disconnected, failed }
    private(set) var state: State = .unavailable
    private(set) var generation: UInt64 = 0
    private(set) var deadline: TimeInterval?
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    mutating func move(_ next: State, timeout: TimeInterval? = nil) -> Bool {
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
