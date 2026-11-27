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
        pending += bytes
        var messages: [[UInt8]] = []
        while pending.count >= 4 {
            let count = pending.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard count <= 4092 else { throw Failure("oversized frame") }
            guard pending.count >= count + 4 else { break }
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
let parser = FrameDecoder()
let sample = frame([1, 2, 3])
guard try parser.feed(Array(sample.prefix(2))).isEmpty, try parser.feed(Array(sample[2..<5])).isEmpty,
      try parser.feed(Array(sample.dropFirst(5)) + frame([4])) == [[1, 2, 3], [4]] else { throw Failure("stream parser") }
try parser.finish()
guard try FrameDecoder().feed(frame([UInt8](repeating: 1, count: 4092))).first?.count == 4092 else { throw Failure("max frame") }
do { _ = try FrameDecoder().feed([0, 0, 16, 0]); throw Failure("accepted oversize") } catch let e as Failure { guard e.message == "oversized frame" else { throw e } }
do { _ = try unframe([0, 0, 0, 3, 42]); throw Failure("accepted incomplete frame") } catch let e as Failure { guard e.message == "incomplete frame" else { throw e } }
precondition(classifyIO(0) == .ok && classifyIO(EWOULDBLOCK) == .wouldBlock && classifyIO(EINVAL) == .ambiguous && classifyIO(EIO) == .fatal)

let dir = CommandLine.arguments[1]
let scenario = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "positive"
func file(_ name: String) -> [UInt8] { Array(try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + name))) }
let caPEM = file("ca.pem"), caDER = file("ca.der"), serverDER = file("server.der"), serverKey = file("server.key.der"), clientDER = file("client.der"), clientPEM = file("client.pem"), clientKey = file("client.key")
let selectedServer = scenario == "expired" ? file("expired.der") : serverDER
var expectedClient = clientDER
if scenario == "wrong-client-pin" { expectedClient[0] ^= 1 }
let trustPEM = scenario == "rogue-root" ? file("rogue-ca.pem") : caPEM
let selectedClientPEM = scenario == "wrong-usage" ? file("server.pem") : scenario == "alternate-client" ? file("alternate.pem") : clientPEM
let selectedClientKey = scenario == "wrong-usage" ? file("server.key") : scenario == "alternate-client" ? file("alternate.key") : clientKey
let started = DispatchTime.now().uptimeNanoseconds
let server = caDER.withUnsafeBufferPointer { ca in selectedServer.withUnsafeBufferPointer { cert in serverKey.withUnsafeBufferPointer { key in expectedClient.withUnsafeBufferPointer { client in
    experiment_server_new(ca.baseAddress, ca.count, cert.baseAddress, cert.count, key.baseAddress, key.count, client.baseAddress, client.count)
} } } }
guard let server else { throw Failure("server init") }
defer { experiment_server_free(server) }
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
if scenario == "inject-builder" { throw Failure("injected builder failure") }
rustls_client_config_builder_set_server_verifier(clientBuilder, verifier)
let alpn = Array((scenario == "wrong-alpn" ? "wrong/1" : "pi-tv-experiment/1").utf8)
if scenario != "missing-alpn" { try check(alpn.withUnsafeBufferPointer { p in var bytes = rustls_slice_bytes(data: p.baseAddress, len: p.count); return rustls_client_config_builder_set_alpn_protocols(clientBuilder, &bytes, 1) }, "alpn") }
var certified: OpaquePointer?
try check(selectedClientPEM.withUnsafeBufferPointer { cert in selectedClientKey.withUnsafeBufferPointer { key in rustls_certified_key_build(cert.baseAddress, cert.count, key.baseAddress, key.count, &certified) } }, "client key")
guard let certified else { throw Failure("key") }
defer { rustls_certified_key_free(certified) }
var keyOpt: OpaquePointer? = certified
if scenario != "missing-client" { try check(rustls_client_config_builder_set_certified_key(clientBuilder, &keyOpt, 1), "client cert") }
if scenario == "inject-config" { throw Failure("injected config failure") }
var config: OpaquePointer?
let buildResult = rustls_client_config_builder_build(clientBuilder, &config)
builder = nil // build consumes the builder on success and failure
try check(buildResult, "client config")
guard let config else { throw Failure("config") }
defer { rustls_client_config_free(config) }
if scenario == "inject-connection" { throw Failure("injected connection failure") }
var client: OpaquePointer?
try check(rustls_client_connection_new(config, scenario == "wrong-host" ? "wrong.test" : "pi-tv.test", &client), "client")
guard let client else { throw Failure("client") }
defer { rustls_connection_free(client) }
rustls_connection_set_buffer_limit(client, 16384)
let clientOwner = Client(client, pin: scenario == "wrong-server-pin" ? [] : serverDER)
defer { clientOwner.fail() }
do { _ = try clientOwner.write([1]); throw Failure("pre-admission client write allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
var premature = [UInt8](repeating: 0, count: 4)
do { _ = try clientOwner.read(&premature); throw Failure("pre-admission client read allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }

final class Buffer {
    var bytes: [UInt8] = []
    var total = 0
    var high = 0
    var lastChunk: [UInt8] = []
    var nextID: UInt64 = 1
    var outstanding: UInt64?
    var receivedID: UInt64 = 0
    func enqueue(_ chunk: [UInt8]) -> Bool {
        guard outstanding == nil, bytes.isEmpty, !chunk.isEmpty, chunk.count <= 4096 else { return false }
        bytes = chunk; lastChunk = chunk; outstanding = nextID; nextID += 1; high = max(high, chunk.count); total += chunk.count
        return true
    }
    func receipt(_ id: UInt64) -> Bool {
        guard bytes.isEmpty, outstanding == id, id == receivedID + 1 else { return false }
        receivedID = id; outstanding = nil; return true
    }
}
let out = Buffer(), input = Buffer()
let writeCB: rustls_write_callback = { ctx, p, n, count in
    let b = Unmanaged<Buffer>.fromOpaque(ctx!).takeUnretainedValue()
    guard b.outstanding == nil else { return EWOULDBLOCK }
    let take = min(n, 127); guard b.enqueue(Array(UnsafeBufferPointer(start: p, count: take))) else { return EIO }; count!.pointee = take; return 0
}
let readCB: rustls_read_callback = { ctx, p, n, count in
    let b = Unmanaged<Buffer>.fromOpaque(ctx!).takeUnretainedValue()
    guard !b.bytes.isEmpty else { return EWOULDBLOCK }
    let take = min(n, b.bytes.count); b.bytes.withUnsafeBufferPointer { p!.update(from: $0.baseAddress!, count: take) }; b.bytes.removeFirst(take); count!.pointee = take; return 0
}
let outPtr = Unmanaged.passUnretained(out).toOpaque(), inPtr = Unmanaged.passUnretained(input).toOpaque()
if scenario == "cancel" {
    let old = clientOwner.generation
    clientOwner.cancel(); clientOwner.cancel()
    do { _ = try clientOwner.access(generation: old) { 1 }; throw Failure("stale generation allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    throw Failure("injected cancellation")
}
let token = clientOwner.generation
try clientOwner.access(generation: token) {
    do { _ = try clientOwner.access(generation: token) { 1 }; throw Failure("reentrancy allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
}
if scenario == "inject-panic" { try check(RUSTLS_RESULT_PANIC.rawValue, "injected") }
var serverBytes = 0
var didCorrupt = false
var closing = false
if scenario == "pre-admission" || scenario == "oversized" {
    let data = [UInt8](repeating: 1, count: scenario == "oversized" ? 4097 : 1)
    let result = data.withUnsafeBufferPointer { p in scenario == "oversized" ? experiment_server_input(server, p.baseAddress, p.count) : experiment_server_write(server, p.baseAddress, p.count) }
    var scratch = [UInt8](repeating: 0, count: 16)
    let after = scratch.withUnsafeMutableBufferPointer { experiment_server_output(server, $0.baseAddress, $0.count) }
    guard result == -1, after == -1 else { throw Failure("terminal server state failed") }
    throw Failure(scenario == "oversized" ? "oversized input rejected" : "pre-admission rejected")
}
func pump() throws {
    if rustls_connection_wants_write(client) && out.outstanding == nil {
        var n = 0; let e: Int32 = scenario == "inject-einval" ? EINVAL : scenario == "inject-eio" ? EIO : scenario == "inject-wouldblock" ? EWOULDBLOCK : rustls_connection_write_tls(client, writeCB, outPtr, &n); switch classifyIO(e) { case .ok: break; case .wouldBlock: return; case .ambiguous: throw Failure("ambiguous FFI I/O failure"); case .fatal: throw Failure("fatal FFI I/O failure \(e)") }
    }
    if !out.bytes.isEmpty {
        guard let id = out.outstanding else { throw Failure("missing chunk id") }
        let incomingID = scenario == "duplicate" && id == 2 ? id - 1 : scenario == "reorder" && id == 2 ? id + 1 : id
        guard incomingID == out.receivedID + 1 else { throw Failure("invalid chunk sequence") }
        if (scenario == "lost-middle" && id == 2) || (scenario == "lost-final" && closing) { out.bytes.removeAll(); return }
        if scenario == "corrupt" && !didCorrupt { out.bytes[0] = 0; didCorrupt = true }
        let n = out.bytes.withUnsafeBufferPointer { experiment_server_input(server, $0.baseAddress, $0.count) }
        guard n > 0 else { throw Failure("server input") }; out.bytes.removeFirst(n)
        if out.bytes.isEmpty, let id = out.outstanding { guard out.receipt(scenario == "invalid-ack" ? id + 1 : id) else { throw Failure("invalid receipt") } }
    }
    if input.outstanding == nil {
        var bytes = [UInt8](repeating: 0, count: 4096)
        let n = bytes.withUnsafeMutableBufferPointer { experiment_server_output(server, $0.baseAddress, $0.count) }
        guard n >= 0 else { throw Failure("server output") }
        if n > 0 { guard input.enqueue(Array(bytes.prefix(n))) else { throw Failure("server queue") }; serverBytes += n }
    }
    if !input.bytes.isEmpty {
        var n = 0; let e = rustls_connection_read_tls(client, readCB, inPtr, &n); guard e == 0, n > 0 else { throw Failure("client read tls \(e)") }
        try check(rustls_connection_process_new_packets(client), "client process")
        if input.bytes.isEmpty, let id = input.outstanding { guard input.receipt(id) else { throw Failure("invalid receipt") } }
    }
}
for _ in 0..<1000 {
    try pump()
    if !rustls_connection_is_handshaking(client) && experiment_server_admit(server) == 1 { break }
    if DispatchTime.now().uptimeNanoseconds - started > 5_000_000_000 { throw Failure("handshake deadline") }
}
guard !rustls_connection_is_handshaking(client), experiment_server_admit(server) == 1 else { throw Failure("handshake incomplete") }
try clientOwner.admit()
var emptyProbe = [UInt8](repeating: 0, count: 1)
guard try clientOwner.read(&emptyProbe) == -1 else { throw Failure("plaintext empty mapping") }
let handshakeMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
let messageStarted = DispatchTime.now().uptimeNanoseconds
let message = frame(Array("swift-to-rust".utf8))
let written = try clientOwner.write(message)
guard written == message.count else { throw Failure("short write") }
let reply = frame(Array("rust-to-swift".utf8))
let replyCount = reply.withUnsafeBufferPointer { experiment_server_write(server, $0.baseAddress, $0.count) }
guard replyCount == reply.count else { throw Failure("server write") }
for _ in 0..<20 { try pump() }
var received = [UInt8](repeating: 0, count: 3)
let serverParser = FrameDecoder()
var serverMessages: [[UInt8]] = []
for _ in 0..<4096 {
    let n = received.withUnsafeMutableBufferPointer { experiment_server_read(server, $0.baseAddress, $0.count) }
    guard n > 0 else { throw Failure("server plaintext") }
    serverMessages += try serverParser.feed(Array(received.prefix(n)))
    if !serverMessages.isEmpty { break }
}
try serverParser.finish()
guard serverMessages == [Array("swift-to-rust".utf8)] else { throw Failure("server plaintext") }
Trace.delivered += 1
if scenario == "replay" {
    let result = out.lastChunk.withUnsafeBufferPointer { experiment_server_input(server, $0.baseAddress, $0.count) }
    guard result == -1 else { throw Failure("replayed ciphertext accepted") }
    throw Failure("replayed ciphertext rejected")
}
for _ in 0..<20 { try pump() }
let clientParser = FrameDecoder()
var clientMessages: [[UInt8]] = []
for _ in 0..<4096 {
    let count = try clientOwner.read(&received)
    guard count > 0 else { throw Failure("client plaintext EOF") }
    clientMessages += try clientParser.feed(Array(received.prefix(count)))
    if !clientMessages.isEmpty { break }
}
try clientParser.finish()
guard clientMessages == [Array("rust-to-swift".utf8)] else { throw Failure("client plaintext mismatch") }
Trace.delivered += 1
var read = 0
let messageMs = Double(DispatchTime.now().uptimeNanoseconds - messageStarted) / 1_000_000
if scenario == "truncate" {
    let eof: rustls_read_callback = { _, _, _, n in n!.pointee = 0; return 0 }
    var consumed = 1
    guard rustls_connection_read_tls(client, eof, nil, &consumed) == 0, consumed == 0 else { throw Failure("EOF injection failed") }
    var count = 0
    let result = received.withUnsafeMutableBufferPointer { rustls_connection_read(client, $0.baseAddress, $0.count, &count) }
    guard result == RUSTLS_RESULT_UNEXPECTED_EOF.rawValue else { throw Failure("missing unexpected EOF") }
    throw Failure("unexpected EOF detected")
}
closing = true
try clientOwner.shutdown()
do { _ = try clientOwner.write([1]); throw Failure("shutdown client write allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
do { _ = try clientOwner.read(&premature); throw Failure("shutdown client read allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
for _ in 0..<20 { try pump() }
let serverEOF = received.withUnsafeMutableBufferPointer { experiment_server_read(server, $0.baseAddress, $0.count) }
guard serverEOF == 0 else { throw Failure("server close_notify") }
guard experiment_server_close(server) == 0 else { throw Failure("server close") }
for _ in 0..<20 { try pump() }
read = -1
try check(received.withUnsafeMutableBufferPointer { rustls_connection_read(client, $0.baseAddress, $0.count, &read) }, "client close")
guard read == 0 else { throw Failure("client close_notify") }
print("TLS=0x0304 cipher=0x\(String(rustls_connection_get_negotiated_ciphersuite(client), radix: 16)) full=1 mutual-pins=1 alpn=pi-tv-experiment/1 handshake_ms=\(handshakeMs) message_ms=\(messageMs) client_cipher=\(out.total) server_cipher=\(serverBytes) queue_high=\(max(out.high,input.high)) messages=2 close_notify=both")
}
let beforeFree = experiment_server_free_count()
do {
    try run()
    guard experiment_server_free_count() == beforeFree + 1 else { throw Failure("server cleanup count") }
} catch {
    guard experiment_server_free_count() == beforeFree + 1 else { fputs("server cleanup count failure\n", stderr); exit(2) }
    let stage = (error as? Failure)?.message ?? "unknown"
    fputs("RESULT rejected stage=\(stage) admitted=\(Trace.admitted) delivered=\(Trace.delivered) cleanup=1\n", stderr); exit(1)
}
