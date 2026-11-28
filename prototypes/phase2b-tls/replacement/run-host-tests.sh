#!/bin/sh
set -eu
cd "$(dirname "$0")"
fixtures=$(mktemp -d "${TMPDIR:-/tmp}/pi-tv-fixtures.XXXXXX")
rogue=$(mktemp -d "${TMPDIR:-/tmp}/pi-tv-rogue.XXXXXX")
source=$(mktemp -d "${TMPDIR:-/tmp}/pi-tv-swift.XXXXXX")
binary=$(mktemp "${TMPDIR:-/tmp}/pi-tv-handshake.XXXXXX")
trap 'rm -rf "$fixtures" "$rogue" "$binary" "$source"' EXIT HUP INT TERM
./fixtures/generate.sh "$fixtures"
./fixtures/generate.sh "$rogue"
cp "$rogue/ca.pem" "$fixtures/rogue-ca.pem"
cargo build --locked --lib
cargo run --locked --bin resumption-probe -- "$fixtures"
cat swift/shared.swift swift/handshake.swift > "$source/main.swift"
swiftc -Xcc -DDEFINE_RING -I swift/CRustls "$source/main.swift" target/debug/libphase2b_replacement_admission.a -framework Security -framework CoreFoundation -liconv -o "$binary"
"$binary" "$fixtures"
"$binary" "$fixtures"
"$binary" "$fixtures" large
"$binary" "$fixtures" delayed-ack
"$binary" "$fixtures" record
"$binary" "$fixtures" event-pump
"$binary" "$fixtures" repeated
/usr/bin/time -l "$binary" "$fixtures" repeated-cancel
for spec in 'expired:client process: 7122' 'wrong-host:client process: 7128' 'wrong-server-pin:server pin' 'wrong-client-pin:server output' 'alternate-client:server output' 'missing-client:server input' 'wrong-alpn:server input' 'missing-alpn:server output' 'tls12:server input' 'corrupt:server input' 'rogue-root:client process: 7127' 'wrong-usage:server input' 'inject-einval:ambiguous FFI I/O failure' 'inject-eio:fatal FFI I/O failure' 'truncate:unexpected EOF detected' 'partial-server-clean:incomplete frame rejected' 'partial-server-eof:incomplete frame rejected' 'partial-client-clean:incomplete frame rejected' 'partial-client-eof:incomplete frame rejected' 'invalid-ack:invalid receipt' 'lost-ack:receipt deadline' 'duplicate:invalid chunk sequence' 'reorder:invalid chunk sequence' 'lost-middle:receipt deadline' 'lost-final:receipt deadline' 'inject-panic:explicit FFI panic result' 'inject-wouldblock:handshake deadline' 'replay:replayed ciphertext rejected' 'previous-replay:replayed ciphertext rejected' 'plaintext-limit:plaintext limit rejected' 'aggregate-budget:aggregate budget rejected' 'cipher-budget:cipher budget rejected' 'context-exhaustion:context limit rejected' 'deferred-event:deferred old event rejected' 'async-pending:scheduled pending cancellation' 'async-receipt:scheduled receipt cancellation' 'cancel-receipt:cancelled delayed receipt' 'cancel-shutdown:cancelled shutdown' 'cancel:injected cancellation' 'cancel-handshake:cancelled handshake' 'cancel-transfer:cancelled transfer' 'pre-admission:pre-admission rejected' 'oversized:oversized input rejected' 'consume-failure:consumed builder failure' 'inject-provider:injected provider failure' 'inject-root-builder:injected root-builder failure' 'inject-root-store:injected root-store failure' 'inject-verifier-builder:injected verifier-builder failure' 'inject-verifier:injected verifier failure' 'inject-certified-key:injected certified-key failure' 'inject-client-config:injected client-config failure' 'inject-builder:injected builder failure' 'inject-config:injected config failure' 'inject-connection:injected connection failure'; do
  scenario=${spec%%:*}
  expected=${spec#*:}
  set +e
  output=$("$binary" "$fixtures" "$scenario" 2>&1)
  result=$?
  set -e
  [ "$result" -eq 1 ] || { printf 'wrong exit %s: %s\n' "$scenario" "$result" >&2; exit 1; }
  case "$scenario" in partial-*) counts='admitted=1 delivered=0';; replay|previous-replay) counts='admitted=1 delivered=1';; cancel-transfer|plaintext-limit) counts='admitted=1 delivered=0';; truncate|lost-final|cancel-shutdown) counts='admitted=1 delivered=2';; *) counts='admitted=0 delivered=0';; esac
  case "$output" in "RESULT rejected stage=$expected"*"$counts cleanup=1") printf 'PASS %s: %s\n' "$scenario" "$output";; *) printf 'unexpected outcome %s: %s\n' "$scenario" "$output" >&2; exit 1;; esac
done
