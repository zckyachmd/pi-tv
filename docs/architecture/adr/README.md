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
