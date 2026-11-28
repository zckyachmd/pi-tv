#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${PITV_GO:?provide the verified Go executable}"
rogue=$(mktemp -d "${TMPDIR:-/tmp}/pitv-rogue.XXXXXX")
fixtures=$(mktemp -d "${TMPDIR:-/tmp}/pitv-interop.XXXXXX")
rustlog=$(mktemp "${TMPDIR:-/tmp}/pitv-rust.XXXXXX")
golog=$(mktemp "${TMPDIR:-/tmp}/pitv-go.XXXXXX")
peer=$(mktemp "${TMPDIR:-/tmp}/pitv-peer.XXXXXX")
swiftpeer=$(mktemp "${TMPDIR:-/tmp}/pitv-swift.XXXXXX")
trap 'rm -rf "$fixtures" "$rogue" "$rustlog" "$golog" "$peer" "$swiftpeer"' EXIT HUP INT TERM
./fixtures/generate.sh "$fixtures"
./fixtures/generate.sh "$rogue"
cp "$rogue/ca.pem" "$fixtures/rogue-ca.pem"
GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off CGO_ENABLED=0 "$PITV_GO" build -o "$peer" independent/peer.go
cargo build --locked --lib --bin independent-server
swiftc -Xcc -DDEFINE_RING -I swift/CRustls swift/independent.swift target/debug/libphase2b_replacement_admission.a -framework Security -framework CoreFoundation -liconv -o "$swiftpeer"
for scenario in positive resumption wrong-pin wrong-host rogue-root wrong-alpn tls12; do
    if [ "$scenario" = resumption ]; then
        PITV_RESUMPTION_PROBE=1 target/debug/independent-server "$fixtures" 127.0.0.1:39183 >"$rustlog" 2>&1 & server_pid=$!
    else
        target/debug/independent-server "$fixtures" 127.0.0.1:39183 >"$rustlog" 2>&1 & server_pid=$!
    fi
    attempt=0; until grep -q READY "$rustlog"; do attempt=$((attempt+1)); [ "$attempt" -lt 100 ] || { kill "$server_pid" 2>/dev/null || :; exit 1; }; sleep 0.05; done
    set +e
    PITV_TEST="$scenario" "$peer" client "$fixtures" 127.0.0.1:39183 >"$golog" 2>&1
    client_exit=$?
    wait "$server_pid"; server_exit=$?
    set -e
    if [ "$scenario" = positive ] || [ "$scenario" = resumption ]; then
        [ "$client_exit" -eq 0 ] && [ "$server_exit" -eq 0 ] && grep -q 'PASS client' "$golog" && grep -q 'PASS rustls-server' "$rustlog" || { cat "$golog" "$rustlog"; exit 1; }
        if [ "$scenario" = resumption ]; then [ "$(grep -c 'PASS client' "$golog")" -eq 2 ] && [ "$(grep -c 'PASS rustls-server' "$rustlog")" -eq 2 ] || exit 1; fi
    else
        case "$scenario" in
            wrong-pin) expected='admission failed';;
            wrong-host) expected='certificate is valid for';;
            rogue-root) expected='certificate signed by unknown authority';;
            wrong-alpn) expected='no application protocol';;
            tls12) expected='protocol version not supported';;
        esac
        [ "$client_exit" -eq 1 ] && [ "$server_exit" -ne 0 ] && grep -Fq "$expected" "$golog" && ! grep -q PASS "$rustlog" || { cat "$golog" "$rustlog"; exit 1; }
    fi
    printf 'go-client scenario=%s client_exit=%s server_exit=%s ' "$scenario" "$client_exit" "$server_exit"
    tail -1 "$golog"
done
for scenario in positive wrong-pin wrong-host rogue-root wrong-alpn tls12; do
    "$peer" server "$fixtures" 127.0.0.1:39184 >"$golog" 2>&1 & server_pid=$!
    attempt=0; until grep -q READY "$golog"; do attempt=$((attempt+1)); [ "$attempt" -lt 100 ] || { kill "$server_pid" 2>/dev/null || :; exit 1; }; sleep 0.05; done
    set +e
    "$swiftpeer" "$fixtures" 39184 "$scenario" >"$rustlog" 2>&1
    client_exit=$?
    wait "$server_pid"; server_exit=$?
    set -e
    if [ "$scenario" = positive ]; then
        [ "$client_exit" -eq 0 ] && [ "$server_exit" -eq 0 ] && grep -q 'PASS swift-client' "$rustlog" && grep -q 'PASS server' "$golog" || { cat "$rustlog" "$golog"; exit 1; }
    else
        case "$scenario" in wrong-pin) expected='server pin';; wrong-host) expected='process: 7128';; rogue-root) expected='process: 7127';; wrong-alpn) expected='process: 7233';; tls12) expected='process: 7219';; esac
        [ "$client_exit" -eq 1 ] && [ "$server_exit" -ne 0 ] && grep -Fq "$expected" "$rustlog" && ! grep -q PASS "$golog" || { cat "$rustlog" "$golog"; exit 1; }
    fi
    printf 'swift-client scenario=%s client_exit=%s server_exit=%s ' "$scenario" "$client_exit" "$server_exit"
    tail -1 "$rustlog"
done
