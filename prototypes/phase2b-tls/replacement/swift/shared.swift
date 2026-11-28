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
final class FrameDecoder {
    private var pending: [UInt8] = []
    func feed(_ bytes: [UInt8]) throws -> [[UInt8]] {
        guard bytes.count <= 4096, pending.count <= 4096, bytes.count <= 8192 - pending.count else { throw Failure("frame input budget") }
        pending += bytes
        var messages: [[UInt8]] = []
        while pending.count >= 4 {
            let count = pending.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard count <= 4092 else { throw Failure("oversized frame") }
            guard pending.count >= count + 4 else { break }
            guard messages.count < 1024 else { throw Failure("frame output budget") }
            messages.append(Array(pending[4..<(4 + count)])); pending.removeFirst(4 + count)
        }
        guard pending.count <= 4096 else { throw Failure("frame buffer limit") }
        return messages
    }
    func finish() throws { guard pending.isEmpty else { throw Failure("incomplete frame") } }
}
func unframe(_ bytes: [UInt8]) throws -> [UInt8] {
    let decoder = FrameDecoder(); let messages = try decoder.feed(bytes); try decoder.finish()
    guard messages.count == 1 else { throw Failure("message count") }
    return messages[0]
}

final class Client {
    enum State { case handshaking, admitted, failed, closing, closed }
    private let handle: OpaquePointer
    private(set) var state: State = .handshaking
    private(set) var generation: UInt64 = 1
    private var inCall = false
    private let thread = Thread.current
    func access<T>(generation token: UInt64, allowClosing: Bool = false, _ body: () throws -> T) throws -> T {
        guard Thread.current === thread, token == generation, state != .failed, state != .closed, (allowClosing || state != .closing), !inCall else { throw Failure("stale or reentrant client operation") }
        inCall = true; defer { inCall = false }
        return try body()
    }
    func cancel() { if state != .failed && state != .closed { state = .failed; generation += 1 } }
    private let pin: [UInt8]
    private let expectedALPN = Array("pi-tv-experiment/1".utf8)
    init(_ handle: OpaquePointer, pin: [UInt8]) { self.handle = handle; self.pin = pin; rustls_connection_set_buffer_limit(handle, 16384) }
    deinit { rustls_connection_free(handle) }
    func wantsWrite() throws -> Bool { try access(generation: generation, allowClosing: true) { rustls_connection_wants_write(handle) } }
    func writeTLS(_ callback: rustls_write_callback, _ user: UnsafeMutableRawPointer?, _ count: inout Int) throws -> Int32 {
        let result = try access(generation: generation, allowClosing: true) { rustls_connection_write_tls(handle, callback, user, &count) }
        if classifyIO(result) == .ambiguous || classifyIO(result) == .fatal { fail() }
        return result
    }
    func readTLS(_ callback: rustls_read_callback, _ user: UnsafeMutableRawPointer?, _ count: inout Int) throws -> Int32 {
        let result = try access(generation: generation, allowClosing: true) { rustls_connection_read_tls(handle, callback, user, &count) }
        if classifyIO(result) == .ambiguous || classifyIO(result) == .fatal { fail() }
        return result
    }
    func process() throws {
        do { try access(generation: generation, allowClosing: true) { try check(rustls_connection_process_new_packets(handle), "client process") } }
        catch { fail(); throw error }
    }
    func rawRead(_ bytes: inout [UInt8], _ count: inout Int, allowClosing: Bool = false) throws -> UInt32 {
        guard state == .admitted || (allowClosing && state == .closing) else { throw Failure("client not admitted") }
        return try access(generation: generation, allowClosing: allowClosing) { bytes.withUnsafeMutableBufferPointer { rustls_connection_read(handle, $0.baseAddress, $0.count, &count) } }
    }
    func cipher() throws -> UInt16 { try access(generation: generation, allowClosing: true) { rustls_connection_get_negotiated_ciphersuite(handle) } }
    func fail() { cancel() }
    func isHandshaking() throws -> Bool { try access(generation: generation) { rustls_connection_is_handshaking(handle) } }
    func admit() throws {
        try access(generation: generation) {
        guard state == .handshaking else { throw Failure("invalid admission state") }
        guard !rustls_connection_is_handshaking(handle), rustls_connection_get_protocol_version(handle) == 0x0304,
              rustls_connection_handshake_kind(handle) == RUSTLS_HANDSHAKE_KIND_FULL else { fail(); throw Failure("protocol/handshake kind") }
        var value: UnsafePointer<UInt8>?; var count = 0
        rustls_connection_get_alpn_protocol(handle, &value, &count)
        guard let value, Array(UnsafeBufferPointer(start: value, count: count)) == expectedALPN else { fail(); throw Failure("ALPN") }
        guard let peer = rustls_connection_get_peer_certificate(handle, 0) else { fail(); throw Failure("server certificate") }
        var der: UnsafePointer<UInt8>?; var length = 0
        do { try check(rustls_certificate_get_der(peer, &der, &length), "server certificate der") } catch { fail(); throw error }
        guard let der, Array(UnsafeBufferPointer(start: der, count: length)) == pin else { fail(); throw Failure("server pin") }
        state = .admitted; Trace.admitted += 1
        }
    }
    func write(_ bytes: [UInt8]) throws -> Int {
        guard state == .admitted else { throw Failure("client not admitted") }
        return try access(generation: generation) {
            var count = 0
            do { try check(bytes.withUnsafeBufferPointer { rustls_connection_write(handle, $0.baseAddress, $0.count, &count) }, "client write") }
            catch { fail(); throw error }
            return count
        }
    }
    func read(_ bytes: inout [UInt8]) throws -> Int {
        guard state == .admitted else { throw Failure("client not admitted") }
        return try access(generation: generation) {
            var count = 0
            let result = bytes.withUnsafeMutableBufferPointer { rustls_connection_read(handle, $0.baseAddress, $0.count, &count) }
            if result == RUSTLS_RESULT_PLAINTEXT_EMPTY.rawValue { return -1 }
            do { try check(result, "client plaintext") } catch { fail(); throw error }
            return count
        }
    }
    func shutdown() throws {
        guard state == .admitted else { throw Failure("client not admitted") }
        try access(generation: generation) { rustls_connection_send_close_notify(handle); state = .closing }
    }
    func finishClose() throws {
        guard state == .closing else { throw Failure("invalid close state") }
        state = .closed; generation += 1
    }
}
