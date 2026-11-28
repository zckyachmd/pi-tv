import CRustls
import Foundation
import Darwin
import Dispatch

enum Trace { static var admitted = 0; static var delivered = 0 }
struct Failure: Error { let message: String; init(_ message: String) { self.message = message } }

func check(_ result: UInt32, _ step: String) throws {
    if result == RUSTLS_RESULT_PANIC.rawValue { throw Failure("explicit FFI panic result at \(step)") }
    guard result == RUSTLS_RESULT_OK.rawValue else { throw Failure("\(step): \(result)") }
}
enum IOErrorClass: Equatable { case ok, wouldBlock, ambiguous, fatal }
func classifyIO(_ result: Int32) -> IOErrorClass {
    switch result { case 0: return .ok; case EWOULDBLOCK: return .wouldBlock; case EINVAL: return .ambiguous; default: return .fatal }
}
func frame(_ payload: [UInt8]) -> [UInt8] {
    precondition(payload.count <= 4092)
    let n = UInt32(payload.count)
    return [UInt8(n >> 24), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)] + payload
}
final class ApplicationBudget {
    static let shared = ApplicationBudget()
    private let lock = NSLock()
    private var current = 0
    private var peak = 0
    var used: Int { lock.lock(); defer { lock.unlock() }; return current }
    var high: Int { lock.lock(); defer { lock.unlock() }; return peak }
    func resetPeak() { lock.lock(); defer { lock.unlock() }; precondition(current == 0); peak = 0 }
    func reserve(_ count: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard count >= 0, count <= 16384 - current else { return false }
        current += count; peak = max(peak, current); return true
    }
    func release(_ count: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(count >= 0 && count <= current); current -= count
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
    init(_ bytes: [UInt8]) { self.bytes = bytes }
    deinit { ApplicationBudget.shared.release(bytes.count + Self.reservationOverhead) }
}
final class FrameDecoder {
    deinit { ApplicationBudget.shared.release(pending.count) }
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
func unframe(_ bytes: [UInt8]) throws -> DecodedMessage {
    let decoder = FrameDecoder(); let messages = try decoder.feed(bytes); try decoder.finish()
    guard messages.count == 1 else { throw Failure("message count") }
    return messages[0]
}

final class Client {
    enum State { case handshaking, admitted, failed, closing, closed }
    private var ownedHandle: OpaquePointer?
    private var handle: OpaquePointer { ownedHandle! }
    private static let countLock = NSLock()
    private static var activeCount = 0
    private static var destroyedCount = 0
    static var destructions: Int { countLock.lock(); defer { countLock.unlock() }; return destroyedCount }
    private var counted = true
    private func releaseContext() {
        Client.countLock.lock(); defer { Client.countLock.unlock() }
        if counted { counted = false; Client.activeCount -= 1 }
    }
    private(set) var state: State = .handshaking
    struct EventToken: Equatable { let context: UUID; let generation: UInt64 }
    private let context = UUID()
    private(set) var generation: UInt64 = 1
    var token: EventToken { EventToken(context: context, generation: generation) }
    func submit(_ event: EventToken, _ body: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in body(self?.callbackValid(event) ?? false) }
    }
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
        Client.countLock.lock()
        guard Client.activeCount == 0 else { Client.countLock.unlock(); throw Failure("client context limit") }
        Client.activeCount += 1; Client.countLock.unlock()
        guard ApplicationBudget.shared.reserve(pin.count) else {
            Client.countLock.lock(); Client.activeCount -= 1; Client.countLock.unlock()
            throw Failure("pin budget")
        }
        do { return Client(try allocate(), pin: pin) }
        catch { ApplicationBudget.shared.release(pin.count); Client.countLock.lock(); Client.activeCount -= 1; Client.countLock.unlock(); throw error }
    }
    private init(_ handle: OpaquePointer, pin: [UInt8]) {
        self.ownedHandle = handle; self.pin = pin; rustls_connection_set_buffer_limit(handle, 16384)
    }
    private func disposeHandle() {
        guard !inCall, let handle = ownedHandle else { return }
        ownedHandle = nil
        rustls_connection_free(handle)
        let pinCount = pin.count; pin = []; ApplicationBudget.shared.release(pinCount)
        Client.countLock.lock(); Client.destroyedCount += 1; Client.countLock.unlock()
        releaseContext()
    }
    deinit {
        if Thread.current === thread { disposeHandle() }
        else if let handle = ownedHandle {
            let pinCount = pin.count
            DispatchQueue.main.async {
                rustls_connection_free(handle)
                ApplicationBudget.shared.release(pinCount)
                Client.countLock.lock(); Client.destroyedCount += 1; Client.activeCount -= 1; Client.countLock.unlock()
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
    func process() throws {
        do { try access(token: token, allowClosing: true) { try check(rustls_connection_process_new_packets(handle), "client process") } }
        catch { fail(); throw error }
    }
    func rawRead(_ bytes: inout [UInt8], _ count: inout Int, allowClosing: Bool = false) throws -> UInt32 {
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
