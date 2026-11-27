#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image='rust:1.100.0-slim-bookworm@sha256:bb875b0f8ce726053e259034848c471840e96bfe591fd52556178ae9a05e6126'
src="$repo_root/prototypes/phase0b-rust-smoke"
out="$repo_root/evidence/phase0b/arm64-build"
mkdir -p "$out/artifacts"
start="$(date +%s)"

{
  printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'builder_image=%s\n' "$image"
  docker run --rm --network=none --platform linux/arm64 \
    --mount "type=bind,src=$src,dst=/src,readonly" \
    --mount "type=bind,src=$out/artifacts,dst=/out" \
    "$image" sh -ec '
      test "$(rustc --version | awk "{print \$2}")" = 1.100.0
      test "$(dpkg --print-architecture)" = arm64
      . /etc/os-release
      test "$VERSION_ID" = 12
      rustc -Vv
      printf "debian=%s %s\n" "$VERSION_ID" "$VERSION_CODENAME"
      printf "libc="; getconf GNU_LIBC_VERSION
      cargo build --locked --release --target aarch64-unknown-linux-gnu --manifest-path /src/Cargo.toml --target-dir /tmp/phase0b-target
      install -m 0755 /tmp/phase0b-target/aarch64-unknown-linux-gnu/release/phase0b-rust-smoke /out/phase0b-rust-smoke
      printf "ELF header\n"
      readelf -h /out/phase0b-rust-smoke | sed -n "/Class:/p; /Data:/p; /Machine:/p; /Type:/p"
      printf "ELF interpreter and dynamic dependencies\n"
      readelf -l /out/phase0b-rust-smoke | grep -F "Requesting program interpreter" || true
      readelf -d /out/phase0b-rust-smoke | grep -E "NEEDED|SONAME" || true
      ldd /out/phase0b-rust-smoke
      printf "GLIBC symbol requirements\n"
      readelf --version-info /out/phase0b-rust-smoke | grep -oE "GLIBC_[0-9]+(\.[0-9]+)*" | sort -Vu
      printf "smoke output\n"
      /out/phase0b-rust-smoke
    '
} 2>&1 | tee "$out/build.log"

duration="$(( $(date +%s) - start ))"
sha="$(shasum -a 256 "$out/artifacts/phase0b-rust-smoke" | awk '{print $1}')"
cat > "$out/metadata.json" <<EOF
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "Apple Silicon; Docker Linux ARM64 VM; Debian 12 bookworm; Rust 1.100.0; glibc 2.36",
  "command": "scripts/phase0b/build-arm64-smoke.sh",
  "duration_seconds": $duration,
  "result": "VERIFIED",
  "artifact_sha256": "$sha",
  "builder_image": "$image",
  "limitations": ["Disposable hello-world only; no product native dependencies.", "No execution on the Raspberry Pi; no runtime compatibility claim."]
}
EOF
printf 'duration_seconds=%s\nartifact_sha256=%s\n' "$duration" "$sha"
