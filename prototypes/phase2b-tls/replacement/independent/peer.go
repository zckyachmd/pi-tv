package main

import (
	"bytes"
	"crypto/tls"
	"crypto/x509"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "peer error:", err)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) != 4 {
		return fmt.Errorf("usage: peer client|server fixture-dir address")
	}
	mode, dir, addr := os.Args[1], os.Args[2], os.Args[3]
	ca, err := os.ReadFile(dir + "/ca.pem")
	if err != nil {
		return err
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(ca) {
		return fmt.Errorf("invalid root")
	}
	role, peer := "client", "server"
	if mode == "server" {
		role, peer = "server", "client"
	} else if mode != "client" {
		return fmt.Errorf("invalid mode")
	}
	if os.Getenv("PITV_TEST") == "alternate-identity" {
		if mode == "client" {
			role = "alternate"
		} else {
			role = "alternate-server"
		}
	}
	cert, err := tls.LoadX509KeyPair(dir+"/"+role+".pem", dir+"/"+role+".key")
	if err != nil {
		return err
	}
	pin, err := os.ReadFile(dir + "/" + peer + ".der")
	if err != nil {
		return err
	}
	cfg := &tls.Config{MinVersion: tls.VersionTLS13, MaxVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}, NextProtos: []string{"pi-tv-experiment/1"}, RootCAs: roots, ClientCAs: roots, ClientAuth: tls.RequireAndVerifyClientCert, ServerName: "pi-tv.test", SessionTicketsDisabled: true}
	switch os.Getenv("PITV_TEST") {
	case "wrong-pin":
		pin[0] ^= 1
	case "wrong-host":
		cfg.ServerName = "wrong.test"
	case "rogue-root":
		cfg.RootCAs = x509.NewCertPool()
	case "wrong-alpn":
		cfg.NextProtos = []string{"wrong/1"}
	case "tls12":
		cfg.MinVersion = tls.VersionTLS12
		cfg.MaxVersion = tls.VersionTLS12
	}
	if os.Getenv("PITV_TEST") == "resumption" {
		cfg.ClientSessionCache = tls.NewLRUClientSessionCache(4)
		cfg.SessionTicketsDisabled = false
		for i := 0; i < 2; i++ {
			if err := runConnection(mode, addr, cfg, pin); err != nil {
				return err
			}
		}
		return nil
	}
	return runConnection(mode, addr, cfg, pin)
}
func runConnection(mode, addr string, cfg *tls.Config, pin []byte) error {
	var err error
	var c net.Conn
	if mode == "server" {
		l, err := net.Listen("tcp", addr)
		if err != nil {
			return err
		}
		defer l.Close()
		fmt.Println("READY")
		c, err = l.Accept()
		if err != nil {
			return err
		}
	} else {
		c, err = net.DialTimeout("tcp", addr, 5*time.Second)
		if err != nil {
			return err
		}
	}
	defer c.Close()
	if err := c.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		return err
	}
	var tc *tls.Conn
	if mode == "server" {
		tc = tls.Server(c, cfg)
	} else {
		tc = tls.Client(c, cfg)
	}
	defer tc.Close()
	if err := tc.Handshake(); err != nil {
		return err
	}
	st := tc.ConnectionState()
	if !st.HandshakeComplete || st.Version != tls.VersionTLS13 || st.DidResume || st.NegotiatedProtocol != "pi-tv-experiment/1" || len(st.VerifiedChains) == 0 || len(st.PeerCertificates) == 0 || !bytes.Equal(st.PeerCertificates[0].Raw, pin) {
		return fmt.Errorf("admission failed")
	}
	if os.Getenv("PITV_TEST") == "client-truncate" && mode == "client" {
		c.Close()
		return fmt.Errorf("injected client unclean close after authentication")
	}
	send, want := []byte("go-to-rustls"), []byte("rustls-to-go")
	if mode == "server" {
		send, want = want, send
	}
	partial := os.Getenv("PITV_TEST") == "partial-clean" || os.Getenv("PITV_TEST") == "partial-eof"
	writeFrame := func(payload []byte) error {
		msg := make([]byte, 4+len(payload))
		binary.BigEndian.PutUint32(msg[:4], uint32(len(payload)))
		copy(msg[4:], payload)
		if partial {
			msg = msg[:7]
		}
		_, err := tc.Write(msg)
		return err
	}
	readFrame := func() error {
		var header [4]byte
		if _, err := io.ReadFull(tc, header[:]); err != nil {
			return err
		}
		size := binary.BigEndian.Uint32(header[:])
		if size > 4092 {
			return fmt.Errorf("frame too large")
		}
		data := make([]byte, size)
		if _, err := io.ReadFull(tc, data); err != nil {
			return err
		}
		if !bytes.Equal(data, want) {
			return fmt.Errorf("message mismatch")
		}
		return nil
	}
	if mode == "client" {
		if err := writeFrame(send); err != nil {
			return err
		}
	}
	if mode == "client" && partial {
		if os.Getenv("PITV_TEST") == "partial-clean" {
			if err := tc.CloseWrite(); err != nil {
				return err
			}
		} else {
			c.Close()
		}
		return fmt.Errorf("injected partial frame")
	}
	if err := readFrame(); err != nil {
		return err
	}
	if mode == "server" {
		if err := writeFrame(send); err != nil {
			return err
		}
	}
	if mode == "server" && partial {
		if os.Getenv("PITV_TEST") == "partial-clean" {
			if err := tc.CloseWrite(); err != nil {
				return err
			}
			time.Sleep(100 * time.Millisecond)
		} else {
			c.Close()
		}
		return fmt.Errorf("injected partial frame")
	}
	if os.Getenv("PITV_TEST") == "truncate" {
		var data [1]byte
		if _, err := tc.Read(data[:]); err != io.EOF {
			return fmt.Errorf("expected client EOF: %v", err)
		}
		c.Close()
		return fmt.Errorf("injected unclean close")
	}
	if err := tc.CloseWrite(); err != nil {
		return err
	}
	if _, err := tc.Write([]byte("after-close")); err == nil {
		return fmt.Errorf("write after close accepted")
	}
	var tail [1]byte
	if n, err := tc.Read(tail[:]); n != 0 || err != io.EOF {
		return fmt.Errorf("authenticated shutdown missing: n=%d err=%v", n, err)
	}
	fmt.Printf("EXCHANGE %s TLS=0x%04x cipher=0x%04x full=true verified=true alpn=%s messages=2 local_close_sent=true peer_eof_observed=true\n", mode, st.Version, st.CipherSuite, st.NegotiatedProtocol)
	return nil
}
