import Foundation
import Network
import Security

public final class BonjourDiscovery {
    private let browser = NWBrowser(for: .bonjour(type: "_pitv._tcp", domain: nil), using: .tcp)

    public init(onResults: @escaping @Sendable ([NWBrowser.Result]) -> Void) {
        browser.browseResultsChangedHandler = { results, _ in onResults(Array(results)) }
    }

    public func start() { browser.start(queue: .main) }
    public func stop() { browser.cancel() }
}

public final class SecureRemote: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let expectedCertificateDER: Data
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private var socket: URLSessionWebSocketTask?
    private let lock = NSLock()

    public init(qrPinnedCertificateDER: Data) {
        expectedCertificateDER = qrPinnedCertificateDER
        super.init()
    }

    public func connect(to url: URL, pairingToken: String) {
        guard url.scheme == "wss" else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(pairingToken)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        lock.lock(); socket = task; lock.unlock()
        task.resume()
    }

    public func send(_ json: Data) async throws {
        let socket = lock.withLock { self.socket }
        guard let socket else { throw URLError(.notConnectedToInternet) }
        try await socket.send(.data(json))
    }

    public func disconnect() {
        lock.lock(); let task = socket; socket = nil; lock.unlock()
        task?.cancel(with: .normalClosure, reason: nil)
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let pinnedCertificate = SecCertificateCreateWithData(nil, expectedCertificateDER as CFData),
              SecTrustSetAnchorCertificates(trust, [pinnedCertificate] as CFArray) == errSecSuccess,
              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
              SecTrustEvaluateWithError(trust, nil),
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first,
              SecCertificateCopyData(leaf) as Data == expectedCertificateDER else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

public enum PairingCredential {
    public static func save(_ token: Data, account: String) throws {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.pitv.host-first",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(key as CFDictionary)
        var query = key
        query.merge([
            kSecValueData as String: token,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { _, new in new }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    public static func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.pitv.host-first",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return value as? Data
    }
}
