# Phase 0B package feasibility

**Result:** verified APT simulations in a disposable Debian 12 ARM64 container; no package was installed. This is not the target Pi's repository configuration or a target install test.

## Environment and reproducibility

- Timestamp: 2026-11-27T07:17:26Z.
- Environment: `rust:1.100.0-slim-bookworm` pinned by digest, Linux ARM64, Debian 12 bookworm repositories.
- Command: `scripts/phase0b/package-feasibility.sh`.
- Duration: 110 seconds.
- Sanitized raw plans: [`evidence/phase0b/package-sim/`](../../../evidence/phase0b/package-sim); run metadata is in `metadata.json`.
- No package install command was executed; `apt-get -s` and `dpkg-deb --build` were used in the throwaway container.

## Resolver results

| Candidate | Direct package candidates | APT changes | Estimated added installed size | Estimated downloads | Result |
|---|---|---:|---:|---:|---|
| Chromium + Cage + D-Bus session + ALSA/PulseAudio clients + GBM/EGL/Wayland + DejaVu fonts | Chromium `156.0.8078.108-1~deb12u1`; Cage `0.1.4-4`; Debian 12 package versions listed in the raw log | 185 new, 0 upgrades, 0 removals | 725,910 KiB (about 709 MiB) | 195,280,960 bytes | Simulated |
| Same, with `pipewire-pulse` | Same; PipeWire `0.3.65-3+deb12u1` | 198 new, 0 upgrades, 0 removals | 737,697 KiB (about 720 MiB) | 197,425,096 bytes | Simulated |
| Chromium + labwc | Debian 12 bookworm ARM64 repository had no `labwc` candidate | Not calculated | Not calculated | Not calculated | **Unavailable** |
| Disposable Rust smoke `.deb` | `phase0b-rust-smoke` 0.1.0, ARM64; `libc6 (>= 2.34)`, `libgcc-s1 (>= 3.0)` | 1 new, 0 upgrades, 0 removals | APT simulation only | Local `.deb` is 144,812 bytes | Simulated |

The Chromium package itself reports `Installed-Size: 276724` KiB and an archive size of 71,043,600 bytes. The dependency estimate is the sum of repository metadata for packages in the APT plan; it excludes user data, display caches and runtime memory, and it must not be compared to the Pi's RAM as though it were a RAM measurement. APT listed five unrelated packages as not upgraded in each plan; the simulations proposed no upgrades or removals.

Debian 12's Chromium package requires `libc6 >= 2.35`, while the Rust smoke binary's maximum referenced glibc symbol was GLIBC 2.34. The Rust result does not change Chromium's dependency floor. Package candidate versions can change as repositories receive updates.

The repository search found no Widevine package candidate. This does not establish whether a lawful vendor-supported integration exists outside the configured Debian repositories. Do not bypass DRM or redistribute a proprietary CDM without authorization.

## Limits and next gate

These plans do not identify the Pi's configured APT sources, current installed packages, available disk space, Raspberry Pi OS package versions, Cage/labwc display behavior, DRM eligibility, or hardware decode. The `.deb` is a disposable packaging smoke test only; it does not test product maintainer scripts, signed repositories, upgrades, removals, rollback, or installation on the device. Re-run simulations against the approved Raspberry Pi OS image metadata before proposing package changes; do not install on the shared Pi without explicit owner authorization.
