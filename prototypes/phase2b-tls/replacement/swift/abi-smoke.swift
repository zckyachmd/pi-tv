import CRustls

let version = rustls_version()
guard let data = version.data else { fatalError("missing rustls version") }
let text = String(decoding: UnsafeBufferPointer(start: UnsafeRawPointer(data).assumingMemoryBound(to: UInt8.self), count: version.len), as: UTF8.self)
guard text == "rustls-ffi/0.15.7/rustls/0.23.46/ring" else { fatalError("unexpected provider: \(text)") }
guard let provider = rustls_ring_crypto_provider() else { fatalError("ring provider unavailable") }
defer { rustls_crypto_provider_free(provider) }
guard rustls_crypto_provider_ciphersuites_len(provider) > 0 else { fatalError("no ciphersuites") }
print(text)
