final class ServerOwner {
    private let handle: OpaquePointer
    private let thread = Thread.current
    private var inCall = false
    init(_ handle: OpaquePointer) { self.handle = handle }
    deinit { experiment_server_free(handle) }
    private func call<T>(_ fallback: T, _ body: (OpaquePointer) -> T) -> T {
        guard Thread.current === thread, !inCall else { return fallback }
        inCall = true; defer { inCall = false }
        return body(handle)
    }
    func input(_ bytes: [UInt8]) -> Int { call(-1) { h in bytes.withUnsafeBufferPointer { experiment_server_input(h, $0.baseAddress, $0.count) } } }
    func output(_ bytes: inout [UInt8]) -> Int { call(-1) { h in bytes.withUnsafeMutableBufferPointer { experiment_server_output(h, $0.baseAddress, $0.count) } } }
    func write(_ bytes: [UInt8]) -> Int { call(-1) { h in bytes.withUnsafeBufferPointer { experiment_server_write(h, $0.baseAddress, $0.count) } } }
    func read(_ bytes: inout [UInt8]) -> Int { call(-1) { h in bytes.withUnsafeMutableBufferPointer { experiment_server_read(h, $0.baseAddress, $0.count) } } }
    func admit() -> Int32 { call(-1) { experiment_server_admit($0) } }
    func close() -> Int32 { call(-1) { experiment_server_close($0) } }
    func eof() -> Int32 { call(-1) { experiment_server_eof($0) } }
}

func run() throws {
do { _ = try FrameDecoder().feed([UInt8](repeating: 0, count: 4097)); throw Failure("accepted input budget") } catch let e as Failure { guard e.message == "frame input budget" else { throw e } }
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
let serverOwner: ServerOwner = try {
    let raw = caDER.withUnsafeBufferPointer { ca in selectedServer.withUnsafeBufferPointer { cert in serverKey.withUnsafeBufferPointer { key in expectedClient.withUnsafeBufferPointer { client in
        experiment_server_new(ca.baseAddress, ca.count, cert.baseAddress, cert.count, key.baseAddress, key.count, client.baseAddress, client.count)
    } } } }
    guard let raw else { throw Failure("server init") }
    return ServerOwner(raw)
}()
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
if scenario == "consume-failure" {
    var unused: OpaquePointer?
    let outcome = rustls_client_config_builder_build(clientBuilder, &unused)
    builder = nil
    guard outcome == RUSTLS_RESULT_NO_SERVER_CERT_VERIFIER.rawValue, unused == nil else { throw Failure("unexpected builder result") }
    throw Failure("consumed builder failure")
}
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
func makeClient() throws -> Client {
    var raw: OpaquePointer?
    try check(rustls_client_connection_new(config, scenario == "wrong-host" ? "wrong.test" : "pi-tv.test", &raw), "client")
    guard let raw else { throw Failure("client") }
    return try Client(raw, pin: scenario == "wrong-server-pin" || scenario == "wrong-pin" ? [] : serverDER)
}
let clientOwner = try makeClient()
defer { clientOwner.fail() }
if scenario == "context-exhaustion" {
    let second = try makeClient()
    guard try second.isHandshaking() else { throw Failure("second context") }
    do { _ = try makeClient(); throw Failure("context limit not enforced") }
    catch let e as Failure { guard e.message == "client context limit" else { throw e } }
    throw Failure("context limit rejected")
}
if scenario == "deferred-event" {
    func expiredEvent() throws -> (Client.EventToken, () -> Bool) {
        var original: Client? = try makeClient()
        let token = original!.token
        weak let weakOriginal = original
        try original!.cancel(); try original!.cancel()
        original = nil
        guard weakOriginal == nil else { throw Failure("old context not destroyed") }
        return (token, { guard let old = weakOriginal else { return false }; return (try? old.access(token: token) { true }) ?? false })
    }
    let (oldToken, event) = try expiredEvent()
    let fresh = try makeClient()
    guard try fresh.isHandshaking(), fresh.token.context != oldToken.context else { throw Failure("fresh context failed") }
    do { _ = try fresh.access(token: oldToken) { 1 }; throw Failure("foreign context token accepted") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    var outcome = "pending"
    DispatchQueue.main.async { outcome = event() ? "accepted" : "rejected" }
    let deadline = Date().addingTimeInterval(1)
    while outcome == "pending" && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.001)) }
    guard outcome == "rejected" else { throw Failure("scheduled stale event accepted or stalled") }
    throw Failure("deferred old event rejected")
}
do { _ = try clientOwner.write([1]); throw Failure("pre-admission client write allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
var premature = [UInt8](repeating: 0, count: 4)
do { _ = try clientOwner.read(&premature); throw Failure("pre-admission client read allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }

final class TestClock { var ticks: UInt64 = 0 }
final class CipherBudget {
    static let shared = CipherBudget()
    private let lock = NSLock()
    private var current = 0
    private var peak = 0
    var used: Int { lock.lock(); defer { lock.unlock() }; return current }
    var high: Int { lock.lock(); defer { lock.unlock() }; return peak }
    func reserve(_ count: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard count >= 0, count <= 8192 - current else { return false }
        current += count; peak = max(peak, current); return true
    }
    func release(_ count: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(count >= 0 && count <= current); current -= count
    }
}
final class Buffer {
    let clock: TestClock
    let budget: CipherBudget
    weak var owner: Client?
    let event: Client.EventToken
    init(clock: TestClock, budget: CipherBudget, owner: Client) { self.clock = clock; self.budget = budget; self.owner = owner; self.event = owner.token }
    deinit { budget.release(bytes.count); ApplicationBudget.shared.release(bytes.count) }
    func consume(_ count: Int) { bytes.removeFirst(count); budget.release(count); ApplicationBudget.shared.release(count) }
    func discard() { budget.release(bytes.count); ApplicationBudget.shared.release(bytes.count); bytes.removeAll() }
    var sentAt: UInt64?
    func checkDeadline() throws {
        if let sentAt, clock.ticks - sentAt >= 40 { throw Failure("receipt deadline") }
    }
    var bytes: [UInt8] = []
    var total = 0
    var high = 0
    var lastChunk: [UInt8] = []
    var nextID: UInt64 = 1
    var outstanding: UInt64?
    var receivedID: UInt64 = 0
    func enqueue(_ chunk: [UInt8]) -> Bool {
        guard outstanding == nil, bytes.isEmpty, !chunk.isEmpty, chunk.count <= 4096, budget.reserve(chunk.count) else { return false }
        guard ApplicationBudget.shared.reserve(chunk.count) else { budget.release(chunk.count); return false }
        bytes = chunk; lastChunk = chunk; sentAt = clock.ticks; outstanding = nextID; nextID += 1; high = max(high, chunk.count); total += chunk.count
        return true
    }
    func receipt(_ id: UInt64) -> Bool {
        guard bytes.isEmpty, outstanding == id, id == receivedID + 1 else { return false }
        receivedID = id; outstanding = nil; sentAt = nil; return true
    }
}
let clock = TestClock()
let cipherBudget = CipherBudget.shared
let out = Buffer(clock: clock, budget: cipherBudget, owner: clientOwner), input = Buffer(clock: clock, budget: cipherBudget, owner: clientOwner)
if scenario == "aggregate-budget" {
    let first = FrameDecoder(), second = FrameDecoder()
    let partial = Array(frame([UInt8](repeating: 0, count: 4092)).prefix(4095))
    guard try first.feed(partial).isEmpty, try second.feed(partial).isEmpty else { throw Failure("aggregate setup") }
    let chunk = [UInt8](repeating: 0, count: 4096)
    guard out.enqueue(chunk), input.enqueue(chunk), ApplicationBudget.shared.used == 16382 else { throw Failure("aggregate setup") }
    do { _ = try FrameDecoder().feed([0, 0, 0]); throw Failure("aggregate limit accepted") }
    catch let error as Failure { guard error.message == "aggregate input budget" else { throw error } }
    out.discard(); input.discard()
    throw Failure("aggregate budget rejected")
}
if scenario == "cipher-budget" {
    let chunk = [UInt8](repeating: 0, count: 4096)
    guard out.enqueue(chunk), input.enqueue(chunk), cipherBudget.used == 8192 else { throw Failure("budget setup") }
    let extra = Buffer(clock: clock, budget: cipherBudget, owner: clientOwner)
    guard !extra.enqueue([1]) else { throw Failure("cipher budget accepted") }
    out.discard(); input.discard()
    guard cipherBudget.used == 0 else { throw Failure("cipher budget cleanup") }
    throw Failure("cipher budget rejected")
}
let writeCB: rustls_write_callback = { ctx, p, n, count in
    let b = Unmanaged<Buffer>.fromOpaque(ctx!).takeUnretainedValue()
    guard let owner = b.owner, owner.callbackValid(b.event) else { return EINVAL }
    guard b.outstanding == nil else { return EWOULDBLOCK }
    let take = min(n, 127); guard b.enqueue(Array(UnsafeBufferPointer(start: p, count: take))) else { return EIO }; count!.pointee = take; return 0
}
let readCB: rustls_read_callback = { ctx, p, n, count in
    let b = Unmanaged<Buffer>.fromOpaque(ctx!).takeUnretainedValue()
    guard let owner = b.owner, owner.callbackValid(b.event) else { return EINVAL }
    guard !b.bytes.isEmpty else { return EWOULDBLOCK }
    let take = min(n, b.bytes.count); b.bytes.withUnsafeBufferPointer { p!.update(from: $0.baseAddress!, count: take) }; b.consume(take); count!.pointee = take; return 0
}
let outPtr = Unmanaged.passUnretained(out).toOpaque(), inPtr = Unmanaged.passUnretained(input).toOpaque()
if scenario == "cancel" {
    let old = clientOwner.token
    try clientOwner.cancel(); try clientOwner.cancel()
    do { _ = try clientOwner.access(token: old) { 1 }; throw Failure("stale generation allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    throw Failure("injected cancellation")
}
let token = clientOwner.token
try clientOwner.access(token: token) {
    do { _ = try clientOwner.access(token: token) { 1 }; throw Failure("reentrancy allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    do { try clientOwner.cancel(); throw Failure("reentrant cancellation allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    do { try clientOwner.finishClose(); throw Failure("reentrant close allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
}
if scenario == "inject-panic" { try check(RUSTLS_RESULT_PANIC.rawValue, "injected") }
var serverBytes = 0
var didCorrupt = false
var closing = false
var delayedOut: (UInt64, Int)?
var delayedIn: (UInt64, Int)?
if scenario == "pre-admission" || scenario == "oversized" {
    let data = [UInt8](repeating: 1, count: scenario == "oversized" ? 4097 : 1)
    let result = scenario == "oversized" ? serverOwner.input(data) : serverOwner.write(data)
    var scratch = [UInt8](repeating: 0, count: 16)
    let after = serverOwner.output(&scratch)
    guard result == -1, after == -1 else { throw Failure("terminal server state failed") }
    throw Failure(scenario == "oversized" ? "oversized input rejected" : "pre-admission rejected")
}
func scheduledCancellation(_ reason: String) throws {
    let old = clientOwner.token
    var outcome = "pending"
    DispatchQueue.main.async {
        do { try clientOwner.cancel(); outcome = "cancelled" } catch { outcome = "failed" }
    }
    let deadline = Date().addingTimeInterval(1)
    while outcome == "pending" && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.001)) }
    guard outcome == "cancelled" else { throw Failure("scheduled cancellation failed") }
    do { _ = try clientOwner.access(token: old) { 1 }; throw Failure("scheduled stale operation accepted") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    throw Failure(reason)
}
func pump() throws {
    clock.ticks += 1
    if Trace.admitted == 0 && (out.total > 65536 || serverBytes > 65536) { throw Failure("handshake input budget") }
    try out.checkDeadline(); try input.checkDeadline()
    if scenario == "async-receipt", delayedOut != nil { try scheduledCancellation("scheduled receipt cancellation") }
    if scenario == "cancel-receipt", delayedOut != nil {
        let old = clientOwner.token; try clientOwner.cancel(); try clientOwner.cancel()
        do { _ = try clientOwner.access(token: old) { 1 }; throw Failure("stale receipt allowed") }
        catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
        throw Failure("cancelled delayed receipt")
    }
    if let (id, count) = delayedOut, scenario != "lost-ack" {
        if count >= 2 { guard out.receipt(id) else { throw Failure("invalid delayed receipt") }; delayedOut = nil }
        else { delayedOut = (id, count + 1) }
    }
    if let (id, count) = delayedIn {
        if count >= 2 { guard input.receipt(id) else { throw Failure("invalid delayed receipt") }; delayedIn = nil }
        else { delayedIn = (id, count + 1) }
    }
    if (try clientOwner.wantsWrite()) && out.outstanding == nil {
        var n = 0; let e: Int32 = scenario == "inject-einval" ? EINVAL : scenario == "inject-eio" ? EIO : scenario == "inject-wouldblock" ? EWOULDBLOCK : (try clientOwner.writeTLS(writeCB, outPtr, &n)); switch classifyIO(e) { case .ok: break; case .wouldBlock: return; case .ambiguous: throw Failure("ambiguous FFI I/O failure"); case .fatal: throw Failure("fatal FFI I/O failure \(e)") }
    }
    if scenario == "async-pending", !out.bytes.isEmpty { try scheduledCancellation("scheduled pending cancellation") }
    if !out.bytes.isEmpty && ((scenario == "cancel-handshake" && Trace.admitted == 0) || (scenario == "cancel-transfer" && Trace.admitted == 1)) {
        let old = clientOwner.token
        try clientOwner.cancel(); try clientOwner.cancel()
        do { _ = try clientOwner.access(token: old) { 1 }; throw Failure("stale callback allowed") }
        catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
        throw Failure(scenario == "cancel-handshake" ? "cancelled handshake" : "cancelled transfer")
    }
    if !out.bytes.isEmpty {
        guard let id = out.outstanding else { throw Failure("missing chunk id") }
        let incomingID = scenario == "duplicate" && id == 2 ? id - 1 : scenario == "reorder" && id == 2 ? id + 1 : id
        guard incomingID == out.receivedID + 1 else { throw Failure("invalid chunk sequence") }
        if (scenario == "lost-middle" && id == 2) || (scenario == "lost-final" && closing) { out.discard(); return }
        if scenario == "corrupt" && !didCorrupt { out.bytes[0] = 0; didCorrupt = true }
        let n = serverOwner.input(out.bytes)
        guard n > 0 else { throw Failure("server input") }; out.consume(n)
        if out.bytes.isEmpty, let id = out.outstanding {
            if scenario == "delayed-ack" || scenario == "lost-ack" || scenario == "cancel-receipt" || scenario == "async-receipt" { delayedOut = (id, 0) }
            else { guard out.receipt(scenario == "invalid-ack" ? id + 1 : id) else { throw Failure("invalid receipt") } }
        }
    }
    if input.outstanding == nil {
        var bytes = [UInt8](repeating: 0, count: 4096)
        let n = serverOwner.output(&bytes)
        guard n >= 0 else { throw Failure("server output") }
        if n > 0 { guard input.enqueue(Array(bytes.prefix(n))) else { throw Failure("server queue") }; serverBytes += n }
    }
    if !input.bytes.isEmpty {
        var n = 0; let e = (try clientOwner.readTLS(readCB, inPtr, &n)); guard e == 0, n > 0 else { throw Failure("client read tls \(e)") }
        try clientOwner.process()
        if input.bytes.isEmpty, let id = input.outstanding {
            if scenario == "delayed-ack" { delayedIn = (id, 0) }
            else { guard input.receipt(id) else { throw Failure("invalid receipt") } }
        }
    }
}
for _ in 0..<1000 {
    try pump()
    if (try !clientOwner.isHandshaking()) && serverOwner.admit() == 1 { break }
    if clock.ticks >= 200 || DispatchTime.now().uptimeNanoseconds - started > 5_000_000_000 { throw Failure("handshake deadline") }
}
guard !(try clientOwner.isHandshaking()), serverOwner.admit() == 1 else { throw Failure("handshake incomplete") }
try clientOwner.admit()
var emptyProbe = [UInt8](repeating: 0, count: 1)
guard try clientOwner.read(&emptyProbe) == -1 else { throw Failure("plaintext empty mapping") }
if scenario == "plaintext-limit" {
    do { _ = try clientOwner.write([UInt8](repeating: 0, count: 4097)); throw Failure("plaintext limit accepted") }
    catch let error as Failure { guard error.message == "plaintext input limit" else { throw error } }
    do { _ = try clientOwner.write([1]); throw Failure("terminal write accepted") }
    catch let error as Failure { guard error.message == "client not admitted" else { throw error } }
    throw Failure("plaintext limit rejected")
}
let handshakeMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
if scenario.hasPrefix("partial-") {
    let partial: [UInt8] = [0, 0, 0, 8, 1, 2, 3]
    let parser = FrameDecoder()
    var bytes = [UInt8](repeating: 0, count: 64)
    if scenario.hasPrefix("partial-server") {
        guard try clientOwner.write(partial) == partial.count else { throw Failure("partial write") }
        for _ in 0..<100 { try pump() }
        let n = serverOwner.read(&bytes)
        guard n == partial.count, try parser.feed(Array(bytes.prefix(n))).isEmpty else { throw Failure("partial delivered") }
        if scenario == "partial-server-clean" {
            try clientOwner.shutdown()
            for _ in 0..<100 { try pump() }
            let closed = serverOwner.read(&bytes)
            guard closed == 0 else { throw Failure("server close missing") }
        } else {
            guard serverOwner.eof() == 0 else { throw Failure("server EOF injection") }
            let result = serverOwner.read(&bytes)
            guard result == -1 else { throw Failure("server truncation accepted") }
        }
    } else {
        let n = serverOwner.write(partial)
        guard n == partial.count else { throw Failure("partial write") }
        for _ in 0..<100 { try pump() }
        let count = try clientOwner.read(&bytes)
        guard count == partial.count, try parser.feed(Array(bytes.prefix(count))).isEmpty else { throw Failure("partial delivered") }
        if scenario == "partial-client-clean" {
            guard serverOwner.close() == 0 else { throw Failure("server close") }
            for _ in 0..<100 { try pump() }
            guard try clientOwner.read(&bytes) == 0 else { throw Failure("client close missing") }
        } else {
            let eof: rustls_read_callback = { _, _, _, n in n!.pointee = 0; return 0 }
            var consumed = 1
            guard try clientOwner.readTLS(eof, nil, &consumed) == 0, consumed == 0 else { throw Failure("client EOF injection") }
            var count = 0
            guard try clientOwner.rawRead(&bytes, &count) == RUSTLS_RESULT_UNEXPECTED_EOF.rawValue else { throw Failure("client truncation accepted") }
        }
    }
    do { try parser.finish(); throw Failure("partial frame accepted") }
    catch let e as Failure { guard e.message == "incomplete frame" else { throw e } }
    throw Failure("incomplete frame rejected")
}
let messageStarted = DispatchTime.now().uptimeNanoseconds
let requestPayload: [UInt8] = scenario == "large" ? [UInt8](repeating: 0x41, count: 4092) : Array("swift-to-rust".utf8)
let replyPayload: [UInt8] = scenario == "large" ? [UInt8](repeating: 0x42, count: 4092) : Array("rust-to-swift".utf8)
let message = frame(requestPayload)
let written = try clientOwner.write(message)
guard written == message.count else { throw Failure("short write") }
let reply = frame(replyPayload)
let replyCount = serverOwner.write(reply)
guard replyCount == reply.count else { throw Failure("server write") }
for _ in 0..<100 { try pump() }
var received = [UInt8](repeating: 0, count: 3)
let serverParser = FrameDecoder()
var serverMessages: [[UInt8]] = []
for _ in 0..<4096 {
    let n = serverOwner.read(&received)
    guard n > 0 else { throw Failure("server plaintext") }
    serverMessages += try serverParser.feed(Array(received.prefix(n)))
    if !serverMessages.isEmpty { break }
}
try serverParser.finish()
guard serverMessages == [requestPayload] else { throw Failure("server plaintext") }
Trace.delivered += 1
if scenario == "record" { try Data(out.lastChunk).write(to: URL(fileURLWithPath: dir + "/previous-ciphertext.bin")) }
if scenario == "replay" || scenario == "previous-replay" {
    let replay = scenario == "previous-replay" ? file("previous-ciphertext.bin") : out.lastChunk
    let result = serverOwner.input(replay)
    guard result == -1 else { throw Failure("replayed ciphertext accepted") }
    throw Failure("replayed ciphertext rejected")
}
for _ in 0..<100 { try pump() }
let clientParser = FrameDecoder()
var clientMessages: [[UInt8]] = []
for _ in 0..<4096 {
    let count = try clientOwner.read(&received)
    guard count > 0 else { throw Failure("client plaintext EOF") }
    clientMessages += try clientParser.feed(Array(received.prefix(count)))
    if !clientMessages.isEmpty { break }
}
try clientParser.finish()
guard clientMessages == [replyPayload] else { throw Failure("client plaintext mismatch") }
Trace.delivered += 1
var read = 0
let messageMs = Double(DispatchTime.now().uptimeNanoseconds - messageStarted) / 1_000_000
if scenario == "truncate" {
    let eof: rustls_read_callback = { _, _, _, n in n!.pointee = 0; return 0 }
    var consumed = 1
    guard try clientOwner.readTLS(eof, nil, &consumed) == 0, consumed == 0 else { throw Failure("EOF injection failed") }
    var count = 0
    let result = try clientOwner.rawRead(&received, &count)
    guard result == RUSTLS_RESULT_UNEXPECTED_EOF.rawValue else { throw Failure("missing unexpected EOF") }
    throw Failure("unexpected EOF detected")
}
closing = true
try clientOwner.shutdown()
if scenario == "cancel-shutdown" {
    let old = clientOwner.token; try clientOwner.cancel(); try clientOwner.cancel()
    do { _ = try clientOwner.access(token: old, allowClosing: true) { 1 }; throw Failure("stale close allowed") }
    catch let e as Failure { guard e.message == "stale or reentrant client operation" else { throw e } }
    throw Failure("cancelled shutdown")
}
do { _ = try clientOwner.write([1]); throw Failure("shutdown client write allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
do { _ = try clientOwner.read(&premature); throw Failure("shutdown client read allowed") } catch let e as Failure { guard e.message == "client not admitted" else { throw e } }
for _ in 0..<100 { try pump() }
let serverEOF = serverOwner.read(&received)
guard serverEOF == 0 else { throw Failure("server close_notify") }
guard serverOwner.close() == 0 else { throw Failure("server close") }
let closedWrite = serverOwner.write(reply)
guard closedWrite == -1 else { throw Failure("server write after close") }
for _ in 0..<100 { try pump() }
read = -1
try check(clientOwner.rawRead(&received, &read, allowClosing: true), "client close")
let cipher = try clientOwner.cipher()
guard read == 0 else { throw Failure("client close_notify") }
try clientOwner.finishClose()
print("TLS=0x0304 cipher=0x\(String(cipher, radix: 16)) full=1 mutual-pins=1 alpn=pi-tv-experiment/1 handshake_ms=\(handshakeMs) message_ms=\(messageMs) client_cipher=\(out.total) server_cipher=\(serverBytes) queue_high=\(max(out.high,input.high)) aggregate_cipher_high=\(cipherBudget.high) aggregate_pending_high=\(ApplicationBudget.shared.high) messages=2 close_notify=both")
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
