use rustls::{
    pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, ServerName},
    server::WebPkiClientVerifier,
    ClientConfig, ClientConnection, HandshakeKind, RootCertStore, ServerConfig, ServerConnection,
};
use std::{
    env, fs,
    io::{Cursor, Read, Write},
    sync::Arc,
};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let dir = env::args().nth(1).ok_or("fixture directory")?;
    let read = |n: &str| fs::read(format!("{dir}/{n}"));
    let mut roots = RootCertStore::empty();
    roots.add(CertificateDer::from(read("ca.der")?))?;
    let roots = Arc::new(roots);
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    let verifier =
        WebPkiClientVerifier::builder_with_provider(roots.clone(), provider.clone()).build()?;
    let server_der = read("server.der")?;
    let server_key = read("server.key.der")?;
    let oversized_chain = vec![CertificateDer::from(server_der.clone()); 256];
    let mut oversized_server = ServerConfig::builder_with_provider(provider.clone())
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_client_cert_verifier(verifier.clone())
        .with_single_cert(
            oversized_chain,
            PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(server_key)),
        )?;
    oversized_server.send_tls13_tickets = 0;
    oversized_server.max_early_data_size = 0;
    let mut server = ServerConfig::builder_with_provider(provider.clone())
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_client_cert_verifier(verifier)
        .with_single_cert(
            vec![CertificateDer::from(read("server.der")?)],
            PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(read("server.key.der")?)),
        )?;
    server.send_tls13_tickets = 2;
    server.max_early_data_size = 1024;
    server.send_half_rtt_data = false;
    let mut client = ClientConfig::builder_with_provider(provider)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_root_certificates(roots)
        .with_client_auth_cert(
            vec![CertificateDer::from(read("client.der")?)],
            PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(read("client.key.der")?)),
        )?;
    client.enable_early_data = true;
    let client = Arc::new(client);
    check_oversized_chain(client.clone(), Arc::new(oversized_server))?;
    let positive = Arc::new(server.clone());
    let mut restricted = server;
    restricted.send_tls13_tickets = 0;
    restricted.max_early_data_size = 0;
    restricted.send_half_rtt_data = false;
    restricted.session_storage = Arc::new(rustls::server::NoServerSessionStorage {});
    if restricted.ticketer.enabled() {
        return Err("stateless ticket enabled".into());
    }
    let restricted = Arc::new(restricted);
    let pins = (read("client.der")?, read("server.der")?);
    let (first, _, _) = connect(client.clone(), positive.clone(), false, false, &pins)?;
    if first != HandshakeKind::Full {
        return Err("initial handshake was not full".into());
    }
    let (second, early, positive_accepted) = connect(client.clone(), positive, true, false, &pins)?;
    if second != HandshakeKind::Resumed || !early || !positive_accepted {
        return Err("positive control did not resume and accept early data".into());
    }
    let (third, early, restricted_accepted) = connect(client, restricted, true, true, &pins)?;
    if third != HandshakeKind::Full || !early || restricted_accepted {
        return Err(
            "restricted handshake did not reject offered ticket with full handshake".into(),
        );
    }
    println!("PASS initial=full positive=resumed positive_early_offered=true positive_early_accepted={positive_accepted} restricted_early_offered=true restricted=full restricted_early_accepted=false application_delivery=0");
    Ok(())
}
fn connect(
    client: Arc<ClientConfig>,
    server: Arc<ServerConfig>,
    offer: bool,
    restricted: bool,
    pins: &(Vec<u8>, Vec<u8>),
) -> Result<(HandshakeKind, bool, bool), Box<dyn std::error::Error>> {
    let mut c = ClientConnection::new(client, ServerName::try_from("pi-tv.test")?.to_owned())?;
    let mut s = ServerConnection::new(server)?;
    let mut offered = false;
    if offer {
        if let Some(mut early) = c.early_data() {
            early.write_all(b"synthetic-early")?;
            offered = true;
        }
    }
    for _ in 0..1000 {
        let mut bytes = Vec::new();
        while c.wants_write() {
            c.write_tls(&mut bytes)?;
        }
        if !bytes.is_empty() {
            s.read_tls(&mut Cursor::new(bytes))?;
            s.process_new_packets()?;
            if restricted && s.early_data().is_some() {
                return Err("restricted server exposed early data".into());
            }
        }
        let mut bytes = Vec::new();
        while s.wants_write() {
            s.write_tls(&mut bytes)?;
        }
        if !bytes.is_empty() {
            c.read_tls(&mut Cursor::new(bytes))?;
            c.process_new_packets()?;
        }
        if !c.is_handshaking() && !s.is_handshaking() && !c.wants_write() && !s.wants_write() {
            if restricted {
                let client_peer = s
                    .peer_certificates()
                    .and_then(|chain| chain.first())
                    .ok_or("missing authenticated client")?;
                let server_peer = c
                    .peer_certificates()
                    .and_then(|chain| chain.first())
                    .ok_or("missing authenticated server")?;
                if client_peer.as_ref() != pins.0
                    || server_peer.as_ref() != pins.1
                    || s.handshake_kind() != Some(HandshakeKind::Full)
                {
                    return Err("restricted peer authentication failed".into());
                }
                if c.is_early_data_accepted() {
                    return Err("restricted early data accepted".into());
                }
                let mut buf = [0; 32];
                match s.reader().read(&mut buf) {
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                    _ => return Err("restricted server delivered application data".into()),
                }
            }
            return Ok((
                c.handshake_kind().ok_or("missing kind")?,
                offered,
                c.is_early_data_accepted(),
            ));
        }
    }
    Err("handshake did not converge".into())
}

fn check_oversized_chain(
    client: Arc<ClientConfig>,
    server: Arc<ServerConfig>,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut c = ClientConnection::new(client, ServerName::try_from("pi-tv.test")?.to_owned())?;
    let mut s = ServerConnection::new(server)?;
    let mut received = 0usize;
    for _ in 0..1000 {
        let mut outbound = Vec::new();
        while c.wants_write() {
            c.write_tls(&mut outbound)?;
        }
        if !outbound.is_empty() {
            s.read_tls(&mut Cursor::new(outbound))?;
            s.process_new_packets()?;
        }
        while s.wants_write() {
            let mut chunk = [0u8; 4096];
            let n = s.write_tls(&mut &mut chunk[..])?;
            if n == 0 {
                return Err("oversized chain stalled".into());
            }
            received += n;
            if received > 65536 {
                if !c.is_handshaking() {
                    return Err("oversized chain authenticated".into());
                }
                println!(
                    "PASS oversized_chain budget=65536 first_rejected_total={received} admitted=0"
                );
                return Ok(());
            }
            c.read_tls(&mut Cursor::new(&chunk[..n]))?;
            if let Err(error) = c.process_new_packets() {
                if !c.is_handshaking() {
                    return Err("oversized chain authenticated".into());
                }
                println!("PASS oversized_chain library_rejection={error:?} received={received} admitted=0");
                return Ok(());
            }
        }
    }
    Err("oversized chain did not exceed budget".into())
}
