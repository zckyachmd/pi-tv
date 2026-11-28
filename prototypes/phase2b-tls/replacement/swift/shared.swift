import CRustls
import Foundation
import Darwin
import Dispatch

enum Trace { static var admitted = 0; static var delivered = 0 }
struct Failure: Error { let message: String; init(_ message: String) { self.message = message } }

enum Ownership {
    struct Counts { var acquired = 0; var freed = 0; var consumed = 0; var borrowed = 0; var retired = 0 }
    private static let lock = NSLock()
    private static var counts: [String: Counts] = [:]
    static func record(_ name: String, _ kind: String) {
        lock.lock(); defer { lock.unlock() }
        var value = counts[name, default: Counts()]
        switch kind {
        case "acquired": value.acquired += 1
        case "freed": value.freed += 1
        case "consumed": value.consumed += 1
        case "borrowed": value.borrowed += 1
        case "retired": value.retired += 1
        default: preconditionFailure("unknown ownership operation")
        }
        precondition(value.freed + value.consumed <= value.acquired && value.retired <= value.acquired)
        counts[name] = value
    }
    static func snapshot() -> [String: Counts] { lock.lock(); defer { lock.unlock() }; return counts }
    static func outstanding() -> Int { snapshot().values.reduce(0) { $0 + $1.acquired - $1.freed - $1.consumed } }
    static func summary() -> String {
        let values = snapshot()
        return values.keys.sorted().map { name in
            let c = values[name]!
            return "\(name):\(c.acquired)/\(c.freed)/\(c.consumed)/\(c.borrowed)/\(c.acquired-c.freed-c.consumed)/\(c.retired)"
        }.joined(separator: ",")
    }
}

func check(_ result: UInt32, _ step: String) throws {
    if result == RUSTLS_RESULT_PANIC.rawValue { throw Failure("explicit FFI panic result at \(step)") }
    guard result == RUSTLS_RESULT_OK.rawValue else { throw Failure("\(step): \(result)") }
}
enum IOErrorClass: Equatable { case ok, wouldBlock, ambiguous, fatal }
func classifyIO(_ result: Int32) -> IOErrorClass {
    switch result { case 0: return .ok; case EWOULDBLOCK: return .wouldBlock; case EINVAL: return .ambiguous; default: return .fatal }
}
final class ApplicationBudget {
    static let shared = ApplicationBudget()
    private let lock = NSLock()
    private var current = 0
    private var peak = 0
    private var reservedBytes = 0
    private var releasedBytes = 0
    var used: Int { lock.lock(); defer { lock.unlock() }; return current }
    var high: Int { lock.lock(); defer { lock.unlock() }; return peak }
    var totals: (Int, Int) { lock.lock(); defer { lock.unlock() }; return (reservedBytes, releasedBytes) }
    func resetPeak() { lock.lock(); defer { lock.unlock() }; precondition(current == 0); peak = 0 }
    func reserve(_ count: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard count >= 0, count <= 16384 - current else { return false }
        current += count; reservedBytes += count; peak = max(peak, current); return true
    }
    func release(_ count: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(count >= 0 && count <= current); current -= count; releasedBytes += count
    }
}
final class DecodedMessage {
    static let reservationOverhead = 32
    private let bytes: [UInt8]
    var count: Int { bytes.count }
    func matches(_ other: [UInt8]) -> Bool { bytes == other }
    func withBytes<T>(_ body: (UnsafeBufferPointer<UInt8>) throws -> T) rethrows -> T {
        try bytes.withUnsafeBufferPointer(body)
    }
    fileprivate init(_ bytes: [UInt8]) { self.bytes = bytes }
    deinit { ApplicationBudget.shared.release(bytes.count + Self.reservationOverhead) }
}
final class FrameDecoder {
    private var reserved = false
    init() throws {
        guard ApplicationBudget.shared.reserve(32) else { throw Failure("aggregate decoder budget") }
        reserved = true
    }
    deinit { if reserved { ApplicationBudget.shared.release(pending.count + 32) } }
    private var pending: [UInt8] = []
    func feed<C: Collection>(_ bytes: C) throws -> [DecodedMessage] where C.Element == UInt8 {
        guard bytes.count <= 4096, pending.count <= 4096, bytes.count <= 8192 - pending.count else { throw Failure("frame input budget") }
        guard ApplicationBudget.shared.reserve(bytes.count) else { throw Failure("aggregate input budget") }
        pending += bytes
        var messages: [DecodedMessage] = []
        while pending.count >= 4 {
            let count = pending.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard count <= 4092 else { throw Failure("oversized frame") }
            guard pending.count >= count + 4 else { break }
            guard messages.count < 1024 else { throw Failure("frame output budget") }
            guard ApplicationBudget.shared.reserve(count + DecodedMessage.reservationOverhead) else { throw Failure("aggregate output budget") }
            messages.append(DecodedMessage(Array(pending[4..<(4 + count)]))); pending.removeFirst(4 + count); ApplicationBudget.shared.release(4 + count)
        }
        guard pending.count <= 4096 else { throw Failure("frame buffer limit") }
        return messages
    }
    func finish() throws { guard pending.isEmpty else { throw Failure("incomplete frame") } }
}

final class EventMailbox {
    static let shared = EventMailbox()
    enum Kind { case transportBytes }
    private final class Event {
        let token: Client.EventToken
        let kind: Kind
        let payload: [UInt8]
        init(token: Client.EventToken, kind: Kind, payload: [UInt8]) { self.token = token; self.kind = kind; self.payload = payload; Ownership.record("event", "acquired") }
        deinit { ApplicationBudget.shared.release(payload.count + 32); Ownership.record("event", "freed") }
    }
    private let lock = NSLock()
    private weak var owner: Client?
    private var events: [Event] = []
    private var scheduled = false
    private var outstanding = 0
    private(set) var accepted = 0
    private(set) var stale = 0
    private(set) var nativeAccess = 0
    private init() {}
    fileprivate func attach(owner: Client) { precondition(Thread.isMainThread); self.owner = owner }
    var pending: Int { lock.lock(); defer { lock.unlock() }; return outstanding }
    func submit<C: Collection>(token: Client.EventToken, kind: Kind, payload: C) -> Bool where C.Element == UInt8 {
        lock.lock(); defer { lock.unlock() }
        guard !payload.isEmpty, payload.count <= 4096, outstanding < 8, ApplicationBudget.shared.reserve(payload.count + 32) else { return false }
        events.append(Event(token: token, kind: kind, payload: Array(payload)))
        outstanding += 1
        if !scheduled {
            scheduled = true
            DispatchQueue.main.async { self.drain() }
        }
        return true
    }
    private func drain() {
        precondition(Thread.isMainThread)
        while true {
            lock.lock()
            guard !events.isEmpty else { scheduled = false; lock.unlock(); return }
            var event: Event? = events.removeFirst()
            lock.unlock()
            if let owner, owner.callbackValid(event!.token) {
                switch event!.kind {
                case .transportBytes:
                    nativeAccess += 1
                    do { try owner.receiveEvent(event!.payload); accepted += 1 }
                    catch { owner.fail() }
                }
            } else { stale += 1 }
            event = nil
            lock.lock(); outstanding -= 1; lock.unlock()
        }
    }
}
func unframe(_ bytes: [UInt8]) throws -> DecodedMessage {
    let decoder = try FrameDecoder(); let messages = try decoder.feed(bytes); try decoder.finish()
    guard messages.count == 1 else { throw Failure("message count") }
    return messages[0]
}

final class Client {
    private struct EventInput { let bytes: UnsafePointer<UInt8>; let count: Int; var offset: Int = 0 }
    enum State { case handshaking, admitted, failed, closing, closed }
    private var ownedHandle: OpaquePointer?
    private var handle: OpaquePointer { ownedHandle! }
    private static let countLock = NSLock()
    private static var activeCount = 0
    private static var destroyedCount = 0
    static var destructions: Int { countLock.lock(); defer { countLock.unlock() }; return destroyedCount }
    static var reservations: Int { countLock.lock(); defer { countLock.unlock() }; return activeCount }
    private var counted = true
    private func releaseContext() {
        Client.countLock.lock(); defer { Client.countLock.unlock() }
        if counted { counted = false; Client.activeCount -= 1; Ownership.record("client-slot", "freed") }
    }
    private(set) var state: State = .handshaking
    struct EventToken: Equatable { let context: UUID; let generation: UInt64 }
    private let context = UUID()
    private(set) var generation: UInt64 = 1
    var token: EventToken { EventToken(context: context, generation: generation) }
    var mailbox: EventMailbox { EventMailbox.shared }
    private var inCall = false
    private let thread = Thread.current
    func callbackValid(_ event: EventToken) -> Bool {
        Thread.current === thread && event == token && state != .failed && state != .closed
    }
    func access<T>(token: EventToken, allowClosing: Bool = false, _ body: () throws -> T) throws -> T {
        guard Thread.current === thread, token == self.token, state != .failed, state != .closed, (allowClosing || state != .closing), !inCall else { throw Failure("stale or reentrant client operation") }
        inCall = true; defer { inCall = false; if state == .failed || state == .closed { disposeHandle() } }
        return try body()
    }
    func cancel() throws {
        guard Thread.current === thread, !inCall else { throw Failure("stale or reentrant client operation") }
        if state != .failed && state != .closed { state = .failed; generation += 1 }
        disposeHandle()
    }
    private var pin: [UInt8]
    private let expectedALPN = Array("pi-tv-experiment/1".utf8)
    static func create(pin: [UInt8], allocate: () throws -> OpaquePointer) throws -> Client {
        guard Thread.isMainThread else { throw Failure("client owner must be main thread") }
        guard pin.count <= 4096 else { throw Failure("pin limit") }
        Client.countLock.lock()
        guard Client.activeCount == 0 else { Client.countLock.unlock(); throw Failure("client context limit") }
        Client.activeCount += 1; Client.countLock.unlock()
        Ownership.record("client-slot", "acquired")
        guard ApplicationBudget.shared.reserve(pin.count) else {
            Client.countLock.lock(); Client.activeCount -= 1; Client.countLock.unlock()
            Ownership.record("client-slot", "freed")
            throw Failure("pin budget")
        }
        do { return Client(try allocate(), pin: pin) }
        catch { ApplicationBudget.shared.release(pin.count); Client.countLock.lock(); Client.activeCount -= 1; Client.countLock.unlock(); Ownership.record("client-slot", "freed"); throw error }
    }
    private init(_ handle: OpaquePointer, pin: [UInt8]) {
        Ownership.record("client-connection", "acquired")
        self.ownedHandle = handle; self.pin = pin; rustls_connection_set_buffer_limit(handle, 16384)
        EventMailbox.shared.attach(owner: self)
    }
    private func disposeHandle() {
        guard !inCall, let handle = ownedHandle else { return }
        precondition(Thread.isMainThread)
        ownedHandle = nil
        rustls_connection_free(handle)
        Ownership.record("client-connection", "freed")
        let pinCount = pin.count; pin = []; ApplicationBudget.shared.release(pinCount)
        Client.countLock.lock(); Client.destroyedCount += 1; Client.countLock.unlock()
        releaseContext()
    }
    deinit {
        if Thread.current === thread { disposeHandle() }
        else if let handle = ownedHandle {
            let pinCount = pin.count
            DispatchQueue.main.async {
                precondition(Thread.isMainThread)
                rustls_connection_free(handle)
                Ownership.record("client-connection", "freed")
                ApplicationBudget.shared.release(pinCount)
                Client.countLock.lock(); Client.destroyedCount += 1; Client.activeCount -= 1; Client.countLock.unlock()
                Ownership.record("client-slot", "freed")
            }
        }
    }
    func wantsWrite() throws -> Bool { try access(token: token, allowClosing: true) { rustls_connection_wants_write(handle) } }
    func writeTLS(_ callback: rustls_write_callback, _ user: UnsafeMutableRawPointer?, _ count: inout Int) throws -> Int32 {
        let result = try access(token: token, allowClosing: true) { rustls_connection_write_tls(handle, callback, user, &count) }
        if classifyIO(result) == .ambiguous || classifyIO(result) == .fatal { fail() }
        return result
    }
    func readTLS(_ callback: rustls_read_callback, _ user: UnsafeMutableRawPointer?, _ count: inout Int) throws -> Int32 {
        let result = try access(token: token, allowClosing: true) { rustls_connection_read_tls(handle, callback, user, &count) }
        if classifyIO(result) == .ambiguous || classifyIO(result) == .fatal { fail() }
        return result
    }
    func receiveEvent(_ bytes: [UInt8]) throws {
        guard !bytes.isEmpty else { throw Failure("empty transport event") }
        let callback: rustls_read_callback = { context, destination, capacity, count in
            let input = context!.assumingMemoryBound(to: EventInput.self)
            let n = min(capacity, input.pointee.count - input.pointee.offset)
            if n > 0 { destination!.update(from: input.pointee.bytes.advanced(by: input.pointee.offset), count: n) }
            input.pointee.offset += n; count!.pointee = n
            return 0
        }
        try bytes.withUnsafeBufferPointer { buffer in
            var input = EventInput(bytes: buffer.baseAddress!, count: buffer.count)
            var count = 0
            let result = try withUnsafeMutablePointer(to: &input) { try readTLS(callback, $0, &count) }
            guard result == 0, count == bytes.count else { throw Failure("transport event input") }
        }
        try process()
    }
    func process() throws {
        do { try access(token: token, allowClosing: true) { try check(rustls_connection_process_new_packets(handle), "client process") } }
        catch { fail(); throw error }
    }
    func rawRead(_ bytes: inout [UInt8], _ count: inout Int, allowClosing: Bool = false) throws -> UInt32 {
        guard bytes.count <= 4096 else { throw Failure("plaintext output limit") }
        guard state == .admitted || (allowClosing && state == .closing) else { throw Failure("client not admitted") }
        let result = try access(token: token, allowClosing: allowClosing) { bytes.withUnsafeMutableBufferPointer { rustls_connection_read(handle, $0.baseAddress, $0.count, &count) } }
        if result != RUSTLS_RESULT_OK.rawValue && result != RUSTLS_RESULT_PLAINTEXT_EMPTY.rawValue { fail() }
        return result
    }
    func cipher() throws -> UInt16 { try access(token: token, allowClosing: true) { rustls_connection_get_negotiated_ciphersuite(handle) } }
    func fail() {
        guard Thread.current === thread else { return }
        if state != .failed && state != .closed { state = .failed; generation += 1 }
        disposeHandle()
    }
    func isHandshaking() throws -> Bool { try access(token: token) { rustls_connection_is_handshaking(handle) } }
    func admit() throws {
        try access(token: token) {
        guard state == .handshaking else { throw Failure("invalid admission state") }
        guard !rustls_connection_is_handshaking(handle), rustls_connection_get_protocol_version(handle) == 0x0304,
              rustls_connection_handshake_kind(handle) == RUSTLS_HANDSHAKE_KIND_FULL else { fail(); throw Failure("protocol/handshake kind") }
        var value: UnsafePointer<UInt8>?; var count = 0
        rustls_connection_get_alpn_protocol(handle, &value, &count)
        guard let value, UnsafeBufferPointer(start: value, count: count).elementsEqual(expectedALPN) else { fail(); throw Failure("ALPN") }
        guard let peer = rustls_connection_get_peer_certificate(handle, 0) else { fail(); throw Failure("server certificate") }
        var der: UnsafePointer<UInt8>?; var length = 0
        do { try check(rustls_certificate_get_der(peer, &der, &length), "server certificate der") } catch { fail(); throw error }
        guard let der, UnsafeBufferPointer(start: der, count: length).elementsEqual(pin) else { fail(); throw Failure("server pin") }
        state = .admitted; Trace.admitted += 1
        }
    }
    func write(_ bytes: [UInt8]) throws -> Int {
        guard state == .admitted else { throw Failure("client not admitted") }
        guard bytes.count <= 4096 else { fail(); throw Failure("plaintext input limit") }
        return try access(token: token) {
            var count = 0
            do { try check(bytes.withUnsafeBufferPointer { rustls_connection_write(handle, $0.baseAddress, $0.count, &count) }, "client write") }
            catch { fail(); throw error }
            return count
        }
    }
    func read(_ bytes: inout [UInt8]) throws -> Int {
        guard bytes.count <= 4096 else { throw Failure("plaintext output limit") }
        guard state == .admitted else { throw Failure("client not admitted") }
        return try access(token: token) {
            var count = 0
            let result = bytes.withUnsafeMutableBufferPointer { rustls_connection_read(handle, $0.baseAddress, $0.count, &count) }
            if result == RUSTLS_RESULT_PLAINTEXT_EMPTY.rawValue { return -1 }
            do { try check(result, "client plaintext") } catch { fail(); throw error }
            return count
        }
    }
    func shutdown() throws {
        guard state == .admitted else { throw Failure("client not admitted") }
        try access(token: token) { rustls_connection_send_close_notify(handle); state = .closing }
    }
    func finishClose() throws {
        try access(token: token, allowClosing: true) {
            guard state == .closing else { throw Failure("invalid close state") }
            state = .closed; generation += 1
        }
    }
}
