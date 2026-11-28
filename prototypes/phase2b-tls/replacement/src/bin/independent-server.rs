use rustls::{
    pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer},
    server::WebPkiClientVerifier,
    RootCertStore, ServerConfig, ServerConnection,
};
use std::{
    env, fs,
    io::{Read, Write},
    net::TcpListener,
    sync::Arc,
    time::Duration,
};
struct TrackedServer(Option<ServerConnection>);
impl std::ops::Deref for TrackedServer {
    type Target = ServerConnection;
    fn deref(&self) -> &Self::Target {
        self.0.as_ref().unwrap()
    }
}
impl std::ops::DerefMut for TrackedServer {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.0.as_mut().unwrap()
    }
}
impl Drop for TrackedServer {
    fn drop(&mut self) {
        drop(self.0.take());
        eprintln!("SERVER_OWNERSHIP acquired=1 freed=1 outstanding=0");
    }
}
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        return Err("usage: independent-server fixtures address".into());
    }
    let read = |name: &str| -> std::io::Result<Vec<u8>> {
        let file = fs::File::open(format!("{}/{}", args[1], name))?;
        let mut bytes = Vec::new();
        file.take(65537).read_to_end(&mut bytes)?;
        if bytes.len() > 65536 {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "fixture limit",
            ));
        }
        Ok(bytes)
    };
    let mut roots = RootCertStore::empty();
    roots.add(CertificateDer::from(read("ca.der")?))?;
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    let verifier =
        WebPkiClientVerifier::builder_with_provider(Arc::new(roots), provider.clone()).build()?;
    let mut config = ServerConfig::builder_with_provider(provider)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_client_cert_verifier(verifier)
        .with_single_cert(
            vec![CertificateDer::from(read("server.der")?)],
            PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(read("server.key.der")?)),
        )?;
    config.alpn_protocols = vec![b"pi-tv-experiment/1".to_vec()];
    config.send_tls13_tickets = 0;
    config.max_early_data_size = 0;
    config.send_half_rtt_data = false;
    config.session_storage = Arc::new(rustls::server::NoServerSessionStorage {});
    if config.ticketer.enabled() {
        return Err("stateless tickets enabled".into());
    }
    let listener = TcpListener::bind(&args[2])?;
    println!("READY");
    let rounds = if env::var("PITV_RESUMPTION_PROBE").is_ok() {
        2
    } else {
        1
    };
    let config = Arc::new(config);
    for _ in 0..rounds {
        let (mut socket, _) = listener.accept()?;
        socket.set_read_timeout(Some(Duration::from_secs(5)))?;
        socket.set_write_timeout(Some(Duration::from_secs(5)))?;
        let mut conn = TrackedServer(Some(ServerConnection::new(config.clone())?));
        while conn.is_handshaking() {
            conn.complete_io(&mut socket)?;
        }
        let peer = conn
            .peer_certificates()
            .and_then(|v| v.first())
            .ok_or("missing client cert")?;
        if peer.as_ref() != read("client.der")?
            || conn.alpn_protocol() != Some(b"pi-tv-experiment/1".as_slice())
            || conn.protocol_version() != Some(rustls::ProtocolVersion::TLSv1_3)
            || conn.handshake_kind() != Some(rustls::HandshakeKind::Full)
        {
            return Err("pin admission failed; admitted=0 delivered=0".into());
        }
        let mut stream = rustls::Stream::new(&mut *conn, &mut socket);
        let mut header = [0; 4];
        if let Err(error) = stream.read_exact(&mut header) {
            if error.kind() == std::io::ErrorKind::UnexpectedEof {
                return Err("unexpected EOF; admitted=1 delivered=0".into());
            }
            return Err(error.into());
        }
        let length = u32::from_be_bytes(header) as usize;
        if length > 4092 {
            return Err("oversized frame; admitted=1 delivered=0".into());
        }
        let mut msg = vec![0; length];
        let mut offset = 0;
        while offset < length {
            match stream.read(&mut msg[offset..]) {
                Ok(0) => {
                    return Err(
                        "incomplete frame authenticated close; admitted=1 delivered=0".into(),
                    )
                }
                Ok(n) => offset += n,
                Err(error) if error.kind() == std::io::ErrorKind::UnexpectedEof => {
                    return Err("incomplete frame unexpected EOF; admitted=1 delivered=0".into())
                }
                Err(error) => return Err(error.into()),
            }
        }
        if msg != b"go-to-rustls" {
            return Err("message mismatch".into());
        }
        stream.write_all(&(12u32.to_be_bytes()))?;
        stream.write_all(b"rustls-to-go")?;
        stream.flush()?;
        if env::var("PITV_TRUNCATE").is_ok() {
            conn.read_tls(&mut socket)?;
            conn.process_new_packets()?;
            println!("INJECTED_TRUNCATION");
            return Ok(());
        }
        conn.send_close_notify();
        while conn.wants_write() {
            conn.write_tls(&mut socket)?;
        }
        loop {
            let mut byte = [0; 1];
            match conn.reader().read(&mut byte) {
                Ok(0) => break,
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    let n = conn.read_tls(&mut socket)?;
                    conn.process_new_packets()?;
                    if n == 0 {
                        return Err("missing authenticated close".into());
                    }
                }
                _ => return Err("unexpected close data or truncation".into()),
            }
        }
        println!(
            "PASS rustls-server TLS=1.3 full=true mutual-pin=true messages=2 close_notify=both"
        );
    }
    Ok(())
}
