# Module boundaries and dependency rules

Proposed, 2026-11-27. Direction: iOS UI → client protocol/session → BLE adapter; Pi BLE adapter → authenticated session → core use cases → ports; adapters implement ports; daemon wires them. Domain and wire definitions cannot import BlueZ, browser, SwiftUI, provider, or systemd. A transport is untrusted bytes plus connection/flow-control events, never an authorization authority. Session authenticates peer and binds identity to each authorized command. Core validates commands, capabilities, lifecycle and state; it does not parse provider DOM or decide trust from advertisements. Runtime port provides start, stop, health, capabilities and typed input/result, with deadlines and generation. Storage port owns atomic trusted state and errors; UI port provides only approved local actions. Adapters translate platform errors and cannot extend command authority.

Keep protocol data transport-neutral; one canonical schema and language-neutral fixtures are candidates, with generated bindings only if toolchain and maintenance pay off. Version and compatibility tests must reject unknown required fields/versions safely. Tests enforce import boundaries, fake transport/runtime failures, contract fixtures, permission and queue limits. No per-feature service, broker, or new crate unless an actual dependency boundary justifies it. The launcher is presentation, not an authorization source. Provider profiles and device credentials do not share storage authority.

## Proposed ownership and dependency constraints

| Location / owner | Public interface and state | Allowed dependencies |
|---|---|---|
| `contracts/` / protocol maintainer | Versioned transport-neutral message schema, compatibility rules and fixtures | Schema tooling only; no platform or provider code. |
| `crates/protocol` / protocol maintainer | Typed codec and validation against contracts; no authorization state | Contracts and standard primitives; no BLE, browser, storage or UI. |
| `crates/core` / core maintainer | Commands, capability policy, authoritative state/revisions, lifecycle and ports | Domain types and narrow ports; no adapter, provider, OS, network or UI imports. |
| `crates/daemon` / platform maintainer | Composition, session authorization and adapters for BLE, storage, runtime and local IPC | Core ports and protocol; adapters do not import one another except through explicitly reviewed composition. |
| `apps/tv-launcher` / launcher maintainer | Presentation and narrowly scoped local actions; focus state is not authorization | Public launcher contract only; never raw CDP, trust-store files or privileged browser bridge. |
| `apps/ios-remote` / mobile maintainer | Native UI, client session and BLE adapter; local UI cache is non-authoritative | Public protocol; no Pi internals, provider credentials or server storage. |
| `packaging/`, `tests/` / release and test maintainers | Installation, contract, integration and acceptance harnesses | Public interfaces and test fixtures, not production bypasses. |

Names indicate responsibilities, not required crate count. Domain must not import transport, secure-channel library, SwiftUI, BlueZ, systemd, browser or provider adapters. Provider pages cannot invoke launcher IPC or debug interfaces. Composition owns wiring; each port owner defines its typed inputs, bounded operations, deadlines, errors and versioning. Adapters map errors without hiding retryability or exposing secrets; rejected, failed and unknown outcomes remain distinct, and no layer converts a timeout into success.

Unit tests exercise core with fake ports; protocol fixtures and fuzz tests cover bounds and version rejection; adapter contract tests exercise errors, cleanup and deadlines; integration tests cover session authorization, storage crash recovery and isolated launcher/browser boundaries. Physical acceptance is separately gated. Future CI should enforce dependency direction via workspace dependency graph/import checks, schema compatibility and forbidden endpoint checks; violations require review, not blanket suppression. These are proposed controls, not existing CI guarantees.
