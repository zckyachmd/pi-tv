# Phase 0B ARM64 Linux build report

**Status: VERIFIED for the disposable build and ELF inspection.** This does not establish runtime compatibility with the Raspberry Pi.

## Reproduction record

- Timestamp: 2026-11-27T06:43:39Z
- Host: Apple Silicon; Docker Linux ARM64 VM.
- Builder: `rust:1.100.0-slim-bookworm@sha256:bb875b0f8ce726053e259034848c471840e96bfe591fd52556178ae9a05e6126`
- Container: Debian 12 bookworm, `arm64`, Rust 1.100.0, glibc 2.36.
- Command: `scripts/phase0b/build-arm64-smoke.sh`
- Cargo command: `cargo build --locked --release --target aarch64-unknown-linux-gnu`
- Build duration: Cargo reported 0.61 seconds; wrapper duration 1 second.
- Source: `prototypes/phase0b-rust-smoke/`; no crates beyond `std`.
- Output: `evidence/phase0b/arm64-build/artifacts/phase0b-rust-smoke`
- SHA-256: `8a906dc228d5ac393b1a7fc727f1568e99c85432b7f2c6af1d8283af06b852d7`

The source mount was read-only, the container network was disabled for the build, and the executable was run inside the ARM64 Linux container.

## Binary inspection

| Check | Result |
|---|---|
| ELF class / encoding | ELF64, little-endian |
| Machine | AArch64 |
| ELF type | PIE (`DYN`) |
| Interpreter | `/lib/ld-linux-aarch64.so.1` |
| Dynamic dependencies | `libgcc_s.so.1`, `libc.so.6` |
| Highest required GLIBC symbol version | GLIBC_2.34 |
| Container glibc | 2.36 |
| Smoke output | `phase0b-arm64-smoke` |

This demonstrates that the pinned Rust compiler can build and execute a minimal dynamically linked AArch64 Linux binary in a Debian 12 ARM64 environment. Debian 12 officially supports arm64 and its release baseline is glibc 2.36. The package version in the actual Raspberry Pi OS image and target execution are still unknown, so compatibility remains **untested**. [Debian 12 release information](https://www.debian.org/News/2023/20230610)

The larger host-first daemon was separately built with its locked dependencies in the same digest-pinned Debian 12 ARM64 image. Its ELF is AArch64 PIE, requires `/lib/ld-linux-aarch64.so.1`, and resolves to `libgcc_s.so.1`, `libm.so.6`, and `libc.so.6` in that builder. Its highest referenced glibc symbol is GLIBC 2.34. The binary is 2.9 MiB and has SHA-256 `c4bb2c22794c0c5ed62d767acb1267f38f2df264f1bf3e99c4d4a7e4de3c6305`. Reproduce with `scripts/phase0b/build-host-first-arm64.sh`; sanitized raw build output and metadata are in `evidence/phase0b/host-first/arm64-artifacts/build.log` and `evidence/phase0b/host-first/arm64-build-metadata.json`. This is still not Pi execution or actual Raspberry Pi OS compatibility evidence.

## Packaging and deployment assessment

The separate package simulation creates a disposable `.deb` containing only this smoke executable and runs APT simulation against it. No package is installed. This checks basic `dpkg-deb` metadata and resolver behavior; it does not validate product maintainer scripts, systemd integration, upgrade/removal, signatures, rollback, or deployment to the Pi. See [PHASE0B_PACKAGE_REPORT.md](PHASE0B_PACKAGE_REPORT.md).

The reproducible image is ARM64 on this ARM64 Docker VM, so this run did not use QEMU. Docker documents QEMU as one option for multi-platform builds and notes emulation can be slower; a CI runner must pin architecture and image digest rather than assume its builder node matches. [Docker multi-platform build strategies](https://docs.docker.com/build/building/multi-platform/)
