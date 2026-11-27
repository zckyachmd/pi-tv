# Architecture decision index

2026-11-27. **Owner-directed** records product constraints; **proposed** records a candidate, not permission to implement. **Validated** requires the listed evidence; **ratified** requires explicit owner approval after review. No candidate here is validated or ratified. Approval authority is product owner, with security/platform review as specified.

| ADR | Direction | Status |
|---|---|---|
| [001](001-transport.md) | BLE and QR enrollment | Owner-directed outcome; GATT implementation proposed |
| [002](002-security.md) | Reviewed secure channel and identities | Proposed; blocked on protocol selection |
| [003](003-platform.md) | Rust core, native iOS and BlueZ adapters | Rust owner-directed; adapters proposed |
| [004](004-runtime.md) | One foreground runtime and isolated launcher | Proposed |
| [005](005-deployment.md) | Dedicated and protected Shared Host | Protection owner-directed; mechanics proposed |
| [006](006-license.md) | GPL-3.0-only and trademark policy | Proposed; legal/distribution review required |

## Remaining decision coverage

These are decision records in this index, not additional ratified ADRs. Owner approval and evidence are required before promotion; existing ADRs remain authoritative for their scope.

| Decision | Status and candidates / trade-off | Evidence and approval gate |
|---|---|---|
| Canonical protocol schema | Proposed: language-neutral schema and fixtures versus manually maintained contracts; generation adds toolchain cost. | Version evolution, bounded decoding and Swift/Rust interoperability; protocol/security review and owner approval. See [protocol](../BLE_PROTOCOL.md). |
| Launcher IPC and browser isolation | Proposed under [004](004-runtime.md): narrow Unix-socket broker versus isolated loopback; private CDP pipe candidate. | Hostile-page, rebinding, local-process and sandbox tests; security and owner approval. |
| Persistence and identity lifecycle | Proposed under [002](002-security.md): atomic files versus transactional storage; crash semantics and migration unresolved. | Power-loss injection, key protection, rotation, backup/reset and local recovery review; security and owner approval. |
| Design system architecture | Proposed: [versioned semantic token contract](../../design/DESIGN_SYSTEM.md) with native platform rendering; deterministic build-time generation or checked mapping, with drift checks. The JSON is the sole active token authority. | Accessibility, focus, localization, overhead and native-platform review; owner approval in later design session. |
| Performance and resource policy | Proposed under [005](005-deployment.md): dedicated and shared profiles with measured resource limits; stronger isolation may reduce playback capacity. | [Benchmark protocol](../BENCHMARKS.md), existing-workload protection and actual target evidence; owner approval. |
| Reference OS and dependencies | Proposed under [003](003-platform.md) and [004](004-runtime.md): Raspberry Pi OS Lite ARM64 and OS-packaged browser candidates, exact versions unresolved. | Supported packages, security updates, licenses, DRM, ABI and physical target comparison; platform and owner approval. |
| Packaging and release | Proposed under [005](005-deployment.md): versioned Debian package, signed APT for public distribution and manual rollback; image deferred. | Clean and interrupted lifecycle, signing, restore and source distribution tests; release and owner approval. |
| iOS licensing and distribution | Owner-directed GPLv3 and separate trademark policy; GPL-3.0-only scope and TestFlight/App Store distribution remain proposed under [006](006-license.md). | Provenance, corresponding source, current platform terms and legal review; owner approval, no compatibility presumption. |
