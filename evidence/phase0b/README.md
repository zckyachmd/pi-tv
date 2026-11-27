# Phase 0B evidence

This directory contains reproducible, sanitized evidence. Each run record must include UTC timestamp, environment, exact command, measured duration, result status, and limitations. Status values: `VERIFIED`, `OWNER_REPORTED`, `PROPOSED`, `FAILED`, `BLOCKED`, `NOT_RUN`.

Keep raw outputs only when they have been reviewed for secrets and private identifiers. Do not capture environment variables, SSH configuration, process command lines, IP addresses, hostnames, account names, browser profiles, tokens, pairing data, or provider content. Target diagnostics in `scripts/phase0b/` emit masked listener addresses and do not print network addresses or hostnames. Put unredacted outputs in a local-only path outside the repository; never commit them.

Each evidence subdirectory should contain `metadata.json` with:

```json
{
  "timestamp_utc": "RFC3339 UTC timestamp",
  "environment": "sanitized OS, architecture, image/toolchain versions",
  "command": "exact command with secrets and private paths removed",
  "duration_seconds": 0,
  "result": "VERIFIED | OWNER_REPORTED | PROPOSED | FAILED | BLOCKED | NOT_RUN",
  "limitations": ["what this evidence does not establish"]
}
```

The host-first run records also carry their relevant metadata inline so the raw browser/API observations stay adjacent to their interpretation. Current evidence paths:

- `arm64-build/` — ARM64 Linux smoke build and ELF inspection.
- `package-sim/` — sanitized Debian 12 Chromium/Cage, PipeWire, labwc and smoke-package APT plans.
- `browser/` — isolated macOS Chrome runtime observations and run metadata.
- `host-first/` — Rust build/test/lint, live local daemon/API lifecycle smoke, and Debian 12 ARM64 daemon ELF build.
- `ios-swift/` — iOS Simulator SDK library compilation and SwiftUI app shell build/install/launch smoke (latest install was blocked by simulator timeout).

The host-first daemon only binds to loopback and has no pairing or LAN authentication. Do not reuse its data or expose it outside a disposable development session. `scripts/phase0b/` contains read-only Pi diagnostics, resource sampling, build/package checks and the Chrome test harness. The Pi diagnostics have not been run because target access was unavailable; scripts do not authorize target mutations.

The ARM64 build uses a digest-pinned Debian 12 ARM64 Rust image. The prototype is disposable and has no product dependencies. A Linux build, ELF inspection, or package simulation does not establish runtime compatibility with the physical Pi.
