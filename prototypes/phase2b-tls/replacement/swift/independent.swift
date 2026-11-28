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
    enum State { case handshaking, admitted, failed, shutdown }
    private let handle: OpaquePointer
    private(set) var state: State = .handshaking
    private(set) var generation: UInt64 = 1
    private var inCall = false
    private let thread = Thread.current
    func access<T>(generation token: UInt64, _ body: () throws -> T) throws -> T {
        guard Thread.current === thread, token == generation, state != .failed, state != .shutdown, !inCall else { throw Failure("stale or reentrant client operation") }
        inCall = true; defer { inCall = false }
        return try body()
    }
    func cancel() { if state != .failed && state != .shutdown { state = .failed; generation += 1 } }
    private let pin: [UInt8]
    private let expectedALPN = Array("pi-tv-experiment/1".utf8)
    init(_ handle: OpaquePointer, pin: [UInt8]) { self.handle = handle; self.pin = pin }
    func fail() { cancel() }
    func admit() throws {
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
        rustls_connection_send_close_notify(handle); state = .shutdown
    }
}

func run() throws {
let dir = CommandLine.arguments[1]
let port = UInt16(CommandLine.arguments[2])!
let scenario = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "positive"
func file(_ n: String) throws -> [UInt8] { Array(try Data(contentsOf: URL(fileURLWithPath: dir + "/" + n))) }
let trustPEM = try file(scenario == "rogue-root" ? "rogue-ca.pem" : "ca.pem"), selectedClientPEM = try file("client.pem"), selectedClientKey = try file("client.key"), serverDER = try file("server.der")
guard let provider = rustls_ring_crypto_provider() else { throw Failure("provider") }
defer { rustls_crypto_provider_free(provider) }
guard let rootBuilder = rustls_root_cert_store_builder_new() else { throw Failure("root builder") }
defer { rustls_root_cert_store_builder_free(rootBuilder) }
try check(trustPEM.withUnsafeBufferPointer { rustls_root_cert_store_builder_add_pem(rootBuilder, $0.baseAddress, $0.count, true) }, "root")
var roots: OpaquePointer?
try check(rustls_root_cert_store_builder_build(rootBuilder, &roots), "roots")
guard let roots else { throw Failure("roots") }
defer { rustls_root_cert_store_free(roots) }
guard let verifierBuilder = rustls_web_pki_server_cert_verifier_builder_new_with_provider(provider, roots) else { throw Failure("verifier builder") }
defer { rustls_web_pki_server_cert_verifier_builder_free(verifierBuilder) }
var verifier: OpaquePointer?
try check(rustls_web_pki_server_cert_verifier_builder_build(verifierBuilder, &verifier), "verifier")
guard let verifier else { throw Failure("verifier") }
defer { rustls_server_cert_verifier_free(verifier) }
var builder: OpaquePointer?
var version: UInt16 = scenario == "tls12" ? 0x0303 : 0x0304
try check(rustls_client_config_builder_new_custom(provider, &version, 1, &builder), "client builder")
guard let clientBuilder = builder else { throw Failure("builder") }
defer { if let builder { rustls_client_config_builder_free(builder) } }
rustls_client_config_builder_set_server_verifier(clientBuilder, verifier)
let alpn = Array((scenario == "wrong-alpn" ? "wrong/1" : "pi-tv-experiment/1").utf8)
try check(alpn.withUnsafeBufferPointer { p in var bytes = rustls_slice_bytes(data: p.baseAddress, len: p.count); return rustls_client_config_builder_set_alpn_protocols(clientBuilder, &bytes, 1) }, "alpn")
var certified: OpaquePointer?
try check(selectedClientPEM.withUnsafeBufferPointer { cert in selectedClientKey.withUnsafeBufferPointer { key in rustls_certified_key_build(cert.baseAddress, cert.count, key.baseAddress, key.count, &certified) } }, "client key")
guard let certified else { throw Failure("key") }
defer { rustls_certified_key_free(certified) }
var keyOpt: OpaquePointer? = certified
try check(rustls_client_config_builder_set_certified_key(clientBuilder, &keyOpt, 1), "client cert")
var config: OpaquePointer?
let buildResult = rustls_client_config_builder_build(clientBuilder, &config)
builder = nil // build consumes the builder on success and failure
try check(buildResult, "client config")
guard let config else { throw Failure("config") }
defer { rustls_client_config_free(config) }
var client: OpaquePointer?
try check(rustls_client_connection_new(config, scenario == "wrong-host" ? "wrong.test" : "pi-tv.test", &client), "client")
guard let client else { throw Failure("client") }
defer { rustls_connection_free(client) }
rustls_connection_set_buffer_limit(client, 16384)
let clientOwner = Client(client, pin: scenario == "wrong-pin" ? [] : serverDER)
defer { clientOwner.fail() }
do { _ = try clientOwner.write([1]); throw Failure("pre-admission client write allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
var premature = [UInt8](repeating: 0, count: 4)
do { _ = try clientOwner.read(&premature); throw Failure("pre-admission client read allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }

let fd = socket(AF_INET, SOCK_STREAM, 0)
guard fd >= 0 else { throw Failure("socket") }
defer { _ = Darwin.close(fd) }
var timeout = timeval(tv_sec: 5, tv_usec: 0)
_ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
_ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
var addr = sockaddr_in(); addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_family = sa_family_t(AF_INET); addr.sin_port = port.bigEndian; addr.sin_addr = in_addr(s_addr: in_addr_t(0x7f000001).bigEndian)
let connected = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
guard connected == 0 else { throw Failure("connect") }
let writer: rustls_write_callback = { user, buf, count, written in
    let fd = user!.assumingMemoryBound(to: Int32.self).pointee
    let n = Darwin.send(fd, buf, count, 0); if n < 0 { return errno }; written!.pointee = n; return 0
}
let reader: rustls_read_callback = { user, buf, count, read in
    let fd = user!.assumingMemoryBound(to: Int32.self).pointee
    let n = Darwin.recv(fd, buf, count, 0); if n < 0 { return errno }; read!.pointee = n; return 0
}
var socketFD = fd
func flush() throws {
    while rustls_connection_wants_write(client) {
        var n = 0; let result = rustls_connection_write_tls(client, writer, &socketFD, &n)
        guard result == 0, n > 0 else { throw Failure("ciphertext write \(result)") }
    }
}
func receive() throws {
    var n = 0; let result = rustls_connection_read_tls(client, reader, &socketFD, &n)
    guard result == 0, n > 0 else { throw Failure("ciphertext read \(result)") }
    try check(rustls_connection_process_new_packets(client), "process")
}
for _ in 0..<100 {
    try flush()
    if !rustls_connection_is_handshaking(client) { break }
    try receive()
}
try flush()
try clientOwner.admit()
let send = Array("go-to-rustls".utf8)
guard try clientOwner.write(send) == send.count else { throw Failure("short write") }
try flush()
try receive()
var message = [UInt8](repeating: 0, count: 128)
let count = try clientOwner.read(&message)
guard Array(message.prefix(count)) == Array("rustls-to-go".utf8) else { throw Failure("message") }
let cipher = rustls_connection_get_negotiated_ciphersuite(client)
try clientOwner.shutdown(); try flush()
print("PASS swift-client TLS=0x0304 cipher=0x\(String(cipher,radix:16)) full=true verified=true alpn=pi-tv-experiment/1 messages=2")
}
do { try run() } catch { fputs("independent failed: \(error)\n", stderr); exit(1) }
