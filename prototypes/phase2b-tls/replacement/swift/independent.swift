func frame(_ payload: [UInt8]) -> [UInt8] {
    precondition(payload.count <= 4092)
    let n = UInt32(payload.count)
    return [UInt8(n >> 24), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)] + payload
}
func run() throws {
let dir = CommandLine.arguments[1]
let port = UInt16(CommandLine.arguments[2])!
let scenario = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "positive"
func file(_ n: String) throws -> [UInt8] {
    let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: dir + "/" + n))
    defer { try? file.close() }
    let data = try file.read(upToCount: 65537) ?? Data()
    guard data.count <= 65536 else { throw Failure("fixture limit") }
    return Array(data)
}
let trustPEM = try file(scenario == "rogue-root" ? "rogue-ca.pem" : "ca.pem"), selectedClientPEM = try file("client.pem"), selectedClientKey = try file("client.key"), serverDER = try file("server.der")
guard let provider = rustls_ring_crypto_provider() else { throw Failure("provider") }
Ownership.record("provider", "acquired")
defer { rustls_crypto_provider_free(provider); Ownership.record("provider", "freed") }
guard let rootBuilder = rustls_root_cert_store_builder_new() else { throw Failure("root builder") }
Ownership.record("root-builder", "acquired")
defer { rustls_root_cert_store_builder_free(rootBuilder); Ownership.record("root-builder", "freed") }
try check(trustPEM.withUnsafeBufferPointer { rustls_root_cert_store_builder_add_pem(rootBuilder, $0.baseAddress, $0.count, true) }, "root")
var roots: OpaquePointer?
let rootsResult = rustls_root_cert_store_builder_build(rootBuilder, &roots)
Ownership.record("root-builder", "retired")
try check(rootsResult, "roots")
guard let roots else { throw Failure("roots") }
Ownership.record("root-store", "acquired")
defer { rustls_root_cert_store_free(roots); Ownership.record("root-store", "freed") }
Ownership.record("provider", "borrowed"); Ownership.record("root-store", "borrowed")
guard let verifierBuilder = rustls_web_pki_server_cert_verifier_builder_new_with_provider(provider, roots) else { throw Failure("verifier builder") }
Ownership.record("verifier-builder", "acquired")
defer { rustls_web_pki_server_cert_verifier_builder_free(verifierBuilder); Ownership.record("verifier-builder", "freed") }
var verifier: OpaquePointer?
let verifierResult = rustls_web_pki_server_cert_verifier_builder_build(verifierBuilder, &verifier)
Ownership.record("verifier-builder", "retired")
try check(verifierResult, "verifier")
guard let verifier else { throw Failure("verifier") }
Ownership.record("verifier", "acquired")
defer { rustls_server_cert_verifier_free(verifier); Ownership.record("verifier", "freed") }
var builder: OpaquePointer?
var version: UInt16 = scenario == "tls12" ? 0x0303 : 0x0304
try check(rustls_client_config_builder_new_custom(provider, &version, 1, &builder), "client builder")
guard let clientBuilder = builder else { throw Failure("builder") }
Ownership.record("config-builder", "acquired")
defer { if let builder { rustls_client_config_builder_free(builder); Ownership.record("config-builder", "freed") } }
Ownership.record("verifier", "borrowed")
rustls_client_config_builder_set_server_verifier(clientBuilder, verifier)
let alpn = Array((scenario == "wrong-alpn" ? "wrong/1" : "pi-tv-experiment/1").utf8)
try check(alpn.withUnsafeBufferPointer { p in var bytes = rustls_slice_bytes(data: p.baseAddress, len: p.count); return rustls_client_config_builder_set_alpn_protocols(clientBuilder, &bytes, 1) }, "alpn")
var certified: OpaquePointer?
try check(selectedClientPEM.withUnsafeBufferPointer { cert in selectedClientKey.withUnsafeBufferPointer { key in rustls_certified_key_build(cert.baseAddress, cert.count, key.baseAddress, key.count, &certified) } }, "client key")
guard let certified else { throw Failure("key") }
Ownership.record("certified-key", "acquired")
defer { rustls_certified_key_free(certified); Ownership.record("certified-key", "freed") }
var keyOpt: OpaquePointer? = certified
Ownership.record("certified-key", "borrowed"); try check(rustls_client_config_builder_set_certified_key(clientBuilder, &keyOpt, 1), "client cert")
var config: OpaquePointer?
let buildResult = rustls_client_config_builder_build(clientBuilder, &config)
builder = nil; Ownership.record("config-builder", "consumed") // build consumes the builder on success and failure
try check(buildResult, "client config")
guard let config else { throw Failure("config") }
Ownership.record("client-config", "acquired")
defer { rustls_client_config_free(config); Ownership.record("client-config", "freed") }
let clientOwner = try Client.create(pin: scenario == "wrong-server-pin" || scenario == "wrong-pin" ? [] : serverDER) {
    var raw: OpaquePointer?
    Ownership.record("client-config", "borrowed")
        try check(rustls_client_connection_new(config, scenario == "wrong-host" ? "wrong.test" : "pi-tv.test", &raw), "client")
    guard let raw else { throw Failure("client") }
    return raw
}
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
let parser = try FrameDecoder()
func flush() throws {
    while (try clientOwner.wantsWrite()) {
        var n = 0; let result = (try clientOwner.writeTLS(writer, &socketFD, &n))
        guard result == 0, n > 0 else { throw Failure("ciphertext write \(result)") }
    }
}
func receive() throws {
    var n = 0; let result = (try clientOwner.readTLS(reader, &socketFD, &n))
    guard result == 0 else { throw Failure("ciphertext read \(result)") }
    if n == 0 {
        var byte = [UInt8](repeating: 0, count: 1), read = 0
        let outcome = try clientOwner.rawRead(&byte, &read, allowClosing: true)
        guard outcome == RUSTLS_RESULT_UNEXPECTED_EOF.rawValue else { throw Failure("unexpected EOF classification") }
        do { try parser.finish() } catch { throw Failure("incomplete frame unexpected EOF") }
        throw Failure("unexpected EOF")
    }
    try clientOwner.process()
}
for _ in 0..<100 {
    try flush()
    if !(try clientOwner.isHandshaking()) { break }
    try receive()
}
try flush()
try clientOwner.admit()
let send = frame(Array("go-to-rustls".utf8))
guard try clientOwner.write(send) == send.count else { throw Failure("short write") }
try flush()
var message = [UInt8](repeating: 0, count: 128), messages: [DecodedMessage] = []
for _ in 0..<100 {
    let count = try clientOwner.read(&message)
    if count == -1 { try receive(); continue }
    if count == 0 { try parser.finish(); throw Failure("message EOF") }
    messages += try parser.feed(message.prefix(count))
    if !messages.isEmpty { break }
}
guard messages.count == 1, messages[0].matches(Array("rustls-to-go".utf8)) else { throw Failure("message") }
try parser.finish()
Trace.delivered += 1
let cipher = try clientOwner.cipher()
try clientOwner.shutdown()
do { _ = try clientOwner.write([1]); throw Failure("write after close accepted") }
catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
try flush()
var closeBuffer = [UInt8](repeating: 0, count: 1), closeCount = 0
var closeResult = try clientOwner.rawRead(&closeBuffer, &closeCount, allowClosing: true)
if closeResult == RUSTLS_RESULT_PLAINTEXT_EMPTY.rawValue {
    try receive()
    closeResult = try clientOwner.rawRead(&closeBuffer, &closeCount, allowClosing: true)
}
try check(closeResult, "independent close")
guard closeCount == 0 else { throw Failure("missing authenticated close") }
try clientOwner.finishClose()
print("PASS swift-client TLS=0x0304 cipher=0x\(String(cipher,radix:16)) full=true verified=true alpn=pi-tv-experiment/1 messages=2 close_notify=both")
}
let before = Client.destructions
do {
    try run()
    guard Client.destructions == before + 1, ApplicationBudget.shared.used == 0, Ownership.outstanding() == 0, Client.reservations == 0, EventMailbox.shared.pending == 0 else { throw Failure("client cleanup count") }
    let totals = ApplicationBudget.shared.totals
    guard totals.0 == totals.1 else { throw Failure("buffer accounting mismatch") }
    print("COUNTERS \(Ownership.summary()) slots=0 budget=0 buffers=\(totals.0)/\(totals.1)")
    print("RESULT completed admitted=\(Trace.admitted) delivered=\(Trace.delivered) cleanup=1")
} catch {
    let totals = ApplicationBudget.shared.totals
    let cleanup = Client.destructions == before + 1 && ApplicationBudget.shared.used == 0 && totals.0 == totals.1 && Ownership.outstanding() == 0 && Client.reservations == 0 && EventMailbox.shared.pending == 0 ? 1 : 0
    let reason = (error as? Failure)?.message ?? "unknown"
    fputs("COUNTERS \(Ownership.summary()) slots=\(Client.reservations) budget=\(ApplicationBudget.shared.used) buffers=\(totals.0)/\(totals.1)\nRESULT rejected reason=\(reason) admitted=\(Trace.admitted) delivered=\(Trace.delivered) cleanup=\(cleanup)\n", stderr)
    exit(cleanup == 1 ? 1 : 2)
}
