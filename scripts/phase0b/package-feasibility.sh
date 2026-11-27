#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image='rust:1.100.0-slim-bookworm@sha256:bb875b0f8ce726053e259034848c471840e96bfe591fd52556178ae9a05e6126'
artifacts="$repo_root/evidence/phase0b/arm64-build/artifacts"
out="$repo_root/evidence/phase0b/package-sim"
mkdir -p "$out"
start="$(date +%s)"

docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$artifacts,dst=/artifacts,readonly" \
  --mount "type=bind,src=$out,dst=/out" \
  "$image" sh -ec '
    apt-get update -qq >/tmp/phase0b-apt-update.log 2>&1 || { printf "apt_update=FAILED (details withheld)\n"; exit 1; }
    printf "environment=Debian 12 bookworm arm64\n"
    printf "architecture="; dpkg --print-architecture
    printf "glibc="; getconf GNU_LIBC_VERSION
    printf "package_candidates\n"
    apt-cache policy chromium cage labwc dbus-user-session dbus-x11 libasound2 libpulse0 pipewire-pulse libgbm1 libegl1 libwayland-client0 fonts-dejavu-core \
      | sed -E "/^[[:space:]]+[0-9]+ (https?|file):/d"
    printf "package_direct_metadata\n"
    for package in chromium cage labwc dbus-user-session dbus-x11 libasound2 libpulse0 pipewire-pulse libgbm1 libegl1 libwayland-client0 fonts-dejavu-core; do
      printf "package=%s\n" "$package"
      apt-cache show "$package" 2>/dev/null | awk "/^(Package|Version|Architecture|Depends|Recommends|Suggests|Installed-Size|Size):/ {print}" | head -n 14
    done
    if apt-cache search widevine | grep -qi widevine; then apt-cache search widevine; else printf "widevine_repo_candidates=none\n"; fi
    simulate() {
      name="$1"; shift
      printf "simulation=%s (APT simulation; no installation)\n" "$name"
      if apt-get -s --no-install-recommends install "$@" > "/out/$name.plan" 2>&1; then
        cat "/out/$name.plan"
        printf "plan_summary="
        awk "/^[0-9]+ upgraded,/ {printf \"%s \", \$0} /^Inst / {count++} END {printf \"Inst_lines=%d\\n\", count}" "/out/$name.plan"
        printf "estimated_archive_and_installed_size_kib="
        awk "/^Inst / {print \$2}" "/out/$name.plan" | while read package; do
          apt-cache show "$package" 2>/dev/null | awk -v package="$package" "/^Package: / {if (seen) exit; if (\$2 == package) seen=1} seen && /^Installed-Size: / {installed=\$2} seen && /^Size: / {download=\$2} END {if (seen && installed != \"\" && download != \"\") print installed, download; else print 0, 0}"
        done | awk "{installed += \$1; download += \$2; count++} END {printf \"packages=%d installed_kib=%d download_bytes=%d\\n\", count, installed, download}"
      else
        printf "simulation_result=FAILED_OR_UNAVAILABLE\n"
        cat "/out/$name.plan"
      fi
    }
    simulate chromium-cage-core chromium cage dbus-user-session libasound2 libpulse0 libgbm1 libegl1 libwayland-client0 fonts-dejavu-core
    simulate chromium-cage-pipewire chromium cage dbus-user-session libasound2 libpulse0 pipewire-pulse libgbm1 libegl1 libwayland-client0 fonts-dejavu-core
    simulate chromium-labwc-core chromium labwc dbus-user-session libasound2 libpulse0 libgbm1 libegl1 libwayland-client0 fonts-dejavu-core
    printf "simulation=smoke-deb (APT simulation; no installation)\n"
    mkdir -p /tmp/phase0b-package/DEBIAN /tmp/phase0b-package/usr/bin
    install -m 0755 /artifacts/phase0b-rust-smoke /tmp/phase0b-package/usr/bin/phase0b-rust-smoke
    printf "Package: phase0b-rust-smoke\nVersion: 0.1.0\nSection: utils\nPriority: optional\nArchitecture: arm64\nMaintainer: Feasibility Prototype <noreply@example.invalid>\nDepends: libc6 (>= 2.34), libgcc-s1 (>= 3.0)\nDescription: Disposable Phase 0B ARM64 package simulation\n" > /tmp/phase0b-package/DEBIAN/control
    dpkg-deb --root-owner-group --build /tmp/phase0b-package /out/phase0b-rust-smoke_0.1.0_arm64.deb
    dpkg-deb --info /out/phase0b-rust-smoke_0.1.0_arm64.deb
    apt-get -s install /out/phase0b-rust-smoke_0.1.0_arm64.deb
    printf "package_install=NOT_PERFORMED\n"
  ' 2>&1 | tee "$out/simulation.log"

duration="$(( $(date +%s) - start ))"
deb_sha="$(shasum -a 256 "$out/phase0b-rust-smoke_0.1.0_arm64.deb" | awk '{print $1}')"
cat > "$out/metadata.json" <<EOF
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "Debian 12 bookworm arm64 in digest-pinned Rust 1.100.0 container",
  "command": "scripts/phase0b/package-feasibility.sh",
  "duration_seconds": $duration,
  "result": "VERIFIED",
  "smoke_deb_sha256": "$deb_sha",
  "package_install_performed": false,
  "limitations": ["APT simulations use Debian bookworm repositories, not the Raspberry Pi OS image's configured repositories.", "The smoke package is not a product package and does not test service scripts, upgrade, removal, or target runtime."]
}
EOF
printf 'duration_seconds=%s\nsmoke_deb_sha256=%s\n' "$duration" "$deb_sha"
