#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image='rust:1.100.0-slim-bookworm@sha256:bb875b0f8ce726053e259034848c471840e96bfe591fd52556178ae9a05e6126'
registry="${CARGO_HOME:-$HOME/.cargo}/registry"
out="$repo_root/evidence/phase0b/host-first/arm64-artifacts"
stage="$(mktemp -d "${TMPDIR:-/tmp}/pitv-host-first-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/daemon" "$stage/web"
cp "$repo_root/prototypes/host-first/daemon/Cargo.toml" "$repo_root/prototypes/host-first/daemon/Cargo.lock" "$stage/daemon/"
cp -R "$repo_root/prototypes/host-first/daemon/src" "$stage/daemon/"
cp -R "$repo_root/prototypes/host-first/web/." "$stage/web/"
mkdir -p "$out"
test -d "$registry" || { echo "Cargo registry cache is required for offline build" >&2; exit 1; }
start="$(date +%s)"

docker run --rm --network=none --platform linux/arm64 \
  --mount "type=bind,src=$stage,dst=/src,readonly" \
  --mount "type=bind,src=$registry,dst=/cargo-home/registry,readonly" \
  --mount "type=bind,src=$out,dst=/out" \
  --env CARGO_HOME=/cargo-home \
  "$image" sh -ec '
    test "$(rustc --version | awk "{print \$2}")" = 1.100.0
    test "$(dpkg --print-architecture)" = arm64
    . /etc/os-release
    test "$VERSION_ID" = 12
    cargo build --offline --locked --release --manifest-path /src/daemon/Cargo.toml --target-dir /tmp/pitv-host-first-target
    install -m 0755 /tmp/pitv-host-first-target/release/pitv-host-first /out/pitv-host-first
    printf "architecture="; dpkg --print-architecture
    printf "glibc="; getconf GNU_LIBC_VERSION
    printf "ELF header\n"
    readelf -h /out/pitv-host-first | sed -n "/Class:/p; /Data:/p; /Machine:/p; /Type:/p"
    printf "ELF interpreter and dynamic dependencies\n"
    readelf -l /out/pitv-host-first | grep -F "Requesting program interpreter" || true
    readelf -d /out/pitv-host-first | grep -E "NEEDED|SONAME" || true
    printf "resolved dynamic dependencies in build environment\n"
    ldd /out/pitv-host-first
    printf "GLIBC symbol requirements\n"
    readelf --version-info /out/pitv-host-first | grep -oE "GLIBC_[0-9]+(\.[0-9]+)*" | sort -Vu
  ' 2>&1 | tee "$out/build.log"

duration="$(( $(date +%s) - start ))"
sha="$(shasum -a 256 "$out/pitv-host-first" | awk '{print $1}')"
cat > "$repo_root/evidence/phase0b/host-first/arm64-build-metadata.json" <<EOF
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "Digest-pinned Debian 12 ARM64 Rust builder with offline Cargo registry cache",
  "command": "scripts/phase0b/build-host-first-arm64.sh",
  "duration_seconds": $duration,
  "result": "VERIFIED",
  "artifact_sha256": "$sha",
  "builder_image": "$image",
  "limitations": ["Build and ELF inspection only; executable was not run on the Pi.", "This does not verify the target image's installed glibc or runtime dependencies."]
}
EOF
printf 'duration_seconds=%s\nartifact_sha256=%s\n' "$duration" "$sha"
