pub use rustls_ffi::*;

use rustls::{
    pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer},
    server::WebPkiClientVerifier,
    HandshakeKind, ProtocolVersion, RootCertStore, ServerConfig, ServerConnection,
};
use std::{
    io::{Cursor, Read, Write},
    slice,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
};

static SERVER_FREES: AtomicUsize = AtomicUsize::new(0);

const ALPN: &[u8] = b"pi-tv-experiment/1";

pub struct Server {
    conn: ServerConnection,
    expected_client: Vec<u8>,
    admitted: bool,
    failed: bool,
    local_closing: bool,
    peer_closed: bool,
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_new(
    ca: *const u8,
    ca_len: usize,
    cert: *const u8,
    cert_len: usize,
    key: *const u8,
    key_len: usize,
    client: *const u8,
    client_len: usize,
) -> *mut Server {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if ca.is_null()
            || cert.is_null()
            || key.is_null()
            || client.is_null()
            || ca_len == 0
            || ca_len > 65536
            || cert_len == 0
            || cert_len > 65536
            || key_len == 0
            || key_len > 16384
            || client_len == 0
            || client_len > 65536
        {
            return std::ptr::null_mut();
        }
        let ca = slice::from_raw_parts(ca, ca_len).to_vec();
        let cert = slice::from_raw_parts(cert, cert_len).to_vec();
        let key = slice::from_raw_parts(key, key_len).to_vec();
        let client = slice::from_raw_parts(client, client_len).to_vec();
        let mut roots = RootCertStore::empty();
        if roots.add(CertificateDer::from(ca)).is_err() {
            return std::ptr::null_mut();
        }
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let verifier =
            match WebPkiClientVerifier::builder_with_provider(Arc::new(roots), provider.clone())
                .build()
            {
                Ok(v) => v,
                Err(_) => return std::ptr::null_mut(),
            };
        let mut config = match ServerConfig::builder_with_provider(provider)
            .with_protocol_versions(&[&rustls::version::TLS13])
        {
            Ok(b) => match b.with_client_cert_verifier(verifier).with_single_cert(
                vec![CertificateDer::from(cert)],
                PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(key)),
            ) {
                Ok(c) => c,
                Err(_) => return std::ptr::null_mut(),
            },
            Err(_) => return std::ptr::null_mut(),
        };
        config.alpn_protocols = vec![ALPN.to_vec()];
        config.send_tls13_tickets = 0;
        config.max_early_data_size = 0;
        let mut conn = match ServerConnection::new(Arc::new(config)) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };
        conn.set_buffer_limit(Some(16384));
        Box::into_raw(Box::new(Server {
            conn,
            expected_client: client,
            admitted: false,
            failed: false,
            local_closing: false,
            peer_closed: false,
        }))
    }))
    .unwrap_or_else(|_| std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_free(server: *mut Server) {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if !server.is_null() {
            drop(Box::from_raw(server));
            SERVER_FREES.fetch_add(1, Ordering::Relaxed);
        }
    }))
    .unwrap_or_else(|_| ())
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_input(
    server: *mut Server,
    data: *const u8,
    len: usize,
) -> isize {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if data.is_null() || len > 4096 {
            s.admitted = false;
            s.failed = true;
            return -1;
        }
        if s.failed || len == 0 {
            return -1;
        }
        match s
            .conn
            .read_tls(&mut Cursor::new(slice::from_raw_parts(data, len)))
        {
            Ok(n) => match s.conn.process_new_packets() {
                Ok(_) => n as isize,
                Err(_) => {
                    s.admitted = false;
                    s.failed = true;
                    -1
                }
            },
            Err(_) => {
                s.admitted = false;
                s.failed = true;
                -1
            }
        }
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_output(
    server: *mut Server,
    data: *mut u8,
    len: usize,
) -> isize {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if data.is_null() || len > 4096 {
            s.admitted = false;
            s.failed = true;
            return -1;
        }
        if s.failed {
            return -1;
        }
        match s
            .conn
            .write_tls(&mut Cursor::new(slice::from_raw_parts_mut(data, len)))
        {
            Ok(n) => n as isize,
            Err(_) => {
                s.admitted = false;
                s.failed = true;
                -1
            }
        }
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_admit(server: *mut Server) -> i32 {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if s.failed {
            return -1;
        }
        if s.conn.is_handshaking() {
            return 0;
        }
        let peer_ok = s
            .conn
            .peer_certificates()
            .and_then(|x| x.first())
            .is_some_and(|c| c.as_ref() == s.expected_client);
        s.admitted = peer_ok
            && s.conn.protocol_version() == Some(ProtocolVersion::TLSv1_3)
            && s.conn.alpn_protocol() == Some(ALPN)
            && s.conn.handshake_kind() == Some(HandshakeKind::Full);
        if s.admitted {
            1
        } else {
            s.failed = true;
            -1
        }
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_write(
    server: *mut Server,
    data: *const u8,
    len: usize,
) -> isize {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if data.is_null() || len > 4096 {
            s.admitted = false;
            s.failed = true;
            return -1;
        }
        if s.failed || s.local_closing || s.peer_closed {
            return -1;
        }
        if !s.admitted {
            s.failed = true;
            return -1;
        }
        match s.conn.writer().write(slice::from_raw_parts(data, len)) {
            Ok(n) => n as isize,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => -2,
            Err(_) => {
                s.admitted = false;
                s.failed = true;
                -1
            }
        }
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_read(
    server: *mut Server,
    data: *mut u8,
    len: usize,
) -> isize {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if data.is_null() || len > 4096 {
            s.admitted = false;
            s.failed = true;
            return -1;
        }
        if s.failed || !s.admitted {
            return -1;
        }
        match s.conn.reader().read(slice::from_raw_parts_mut(data, len)) {
            Ok(0) => {
                s.peer_closed = true;
                0
            }
            Ok(n) => n as isize,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => -2,
            Err(_) => {
                s.admitted = false;
                s.failed = true;
                -1
            }
        }
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub unsafe extern "C" fn experiment_server_close(server: *mut Server) -> i32 {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if server.is_null() {
            return -1;
        }
        let s = &mut *server;
        if s.failed || !s.admitted || s.local_closing {
            return -1;
        }
        s.conn.send_close_notify();
        s.local_closing = true;
        0
    }))
    .unwrap_or_else(|_| {
        if !server.is_null() {
            (*server).admitted = false;
            (*server).failed = true;
        }
        -1
    })
}

#[no_mangle]
pub extern "C" fn experiment_server_free_count() -> usize {
    SERVER_FREES.load(Ordering::Relaxed)
}
