#!/bin/sh
set -eu
cd "$(dirname "$0")"
fixtures=$(mktemp -d "${TMPDIR:-/tmp}/pi-tv-fixtures.XXXXXX")
rogue=$(mktemp -d "${TMPDIR:-/tmp}/pi-tv-rogue.XXXXXX")
binary=$(mktemp "${TMPDIR:-/tmp}/pi-tv-handshake.XXXXXX")
trap 'rm -rf "$fixtures" "$rogue" "$binary"' EXIT HUP INT TERM
./fixtures/generate.sh "$fixtures"
./fixtures/generate.sh "$rogue"
cp "$rogue/ca.pem" "$fixtures/rogue-ca.pem"
cargo build --locked --lib
swiftc -Xcc -DDEFINE_RING -I swift/CRustls swift/handshake.swift target/debug/libphase2b_replacement_admission.a -framework Security -framework CoreFoundation -liconv -o "$binary"
"$binary" "$fixtures"
"$binary" "$fixtures"
for spec in 'expired:client process: 7122' 'wrong-host:client process: 7128' 'wrong-server-pin:server pin' 'wrong-client-pin:server output' 'alternate-client:server output' 'missing-client:server input' 'wrong-alpn:server input' 'missing-alpn:server output' 'tls12:server input' 'corrupt:server input' 'rogue-root:client process: 7127' 'wrong-usage:server input' 'inject-einval:ambiguous FFI I/O failure' 'inject-eio:fatal FFI I/O failure' 'truncate:unexpected EOF detected' 'invalid-ack:invalid receipt' 'duplicate:invalid chunk sequence' 'reorder:invalid chunk sequence' 'lost-middle:handshake incomplete' 'lost-final:server close_notify' 'inject-panic:explicit FFI panic result' 'inject-wouldblock:handshake incomplete' 'replay:replayed ciphertext rejected' 'cancel:injected cancellation' 'pre-admission:pre-admission rejected' 'oversized:oversized input rejected' 'inject-builder:injected builder failure' 'inject-config:injected config failure' 'inject-connection:injected connection failure'; do
  scenario=${spec%%:*}
  expected=${spec#*:}
  set +e
  output=$("$binary" "$fixtures" "$scenario" 2>&1)
  result=$?
  set -e
  [ "$result" -eq 1 ] || { printf 'wrong exit %s: %s\n' "$scenario" "$result" >&2; exit 1; }
  case "$scenario" in replay) counts='admitted=1 delivered=1';; truncate|lost-final) counts='admitted=1 delivered=2';; *) counts='admitted=0 delivered=0';; esac
  case "$output" in "RESULT rejected stage=$expected"*"$counts cleanup=1") printf 'PASS %s: %s\n' "$scenario" "$output";; *) printf 'unexpected outcome %s: %s\n' "$scenario" "$output" >&2; exit 1;; esac
done
