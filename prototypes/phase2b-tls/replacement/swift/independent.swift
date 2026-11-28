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
let clientOwner = try Client.create(pin: scenario == "wrong-server-pin" || scenario == "wrong-pin" ? [] : serverDER) {
    var raw: OpaquePointer?
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
let parser = FrameDecoder()
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
    guard Client.destructions == before + 1, ApplicationBudget.shared.used == 0 else { throw Failure("client cleanup count") }
    print("RESULT completed admitted=\(Trace.admitted) delivered=\(Trace.delivered) cleanup=1")
} catch {
    let cleanup = Client.destructions == before + 1 && ApplicationBudget.shared.used == 0 ? 1 : 0
    let reason = (error as? Failure)?.message ?? "unknown"
    fputs("RESULT rejected reason=\(reason) admitted=\(Trace.admitted) delivered=\(Trace.delivered) cleanup=\(cleanup)\n", stderr)
    exit(cleanup == 1 ? 1 : 2)
}
