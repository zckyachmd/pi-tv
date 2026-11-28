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
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        return Err("usage: independent-server fixtures address".into());
    }
    let read = |name: &str| fs::read(format!("{}/{}", args[1], name));
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
        let mut conn = ServerConnection::new(config.clone())?;
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
            return Err("admission failed".into());
        }
        let mut stream = rustls::Stream::new(&mut conn, &mut socket);
        let mut msg = [0; 12];
        stream.read_exact(&mut msg)?;
        if &msg != b"go-to-rustls" {
            return Err("message mismatch".into());
        }
        stream.write_all(b"rustls-to-go")?;
        stream.flush()?;
        println!("PASS rustls-server TLS=1.3 full=true mutual-pin=true messages=2");
        conn.send_close_notify();
        while conn.wants_write() {
            conn.write_tls(&mut socket)?;
        }
    }
    Ok(())
}
