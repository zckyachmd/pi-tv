# Architecture specification candidate

## System boundaries
```
iPhone SwiftUI -> CoreBluetooth Central -> BLE GATT -> BlueZ / Rust BLE adapter
                                                       |
                              authenticated session -> command dispatcher
                                                       |
                          application core -> lifecycle / runtime / device ports
                                          |                 |
                                  local TV UI IPC     Chromium process tree
                                          |                 |
                                  launcher browser    Wayland / labwc or Cage
                                                            |
                                               Linux / GPU / audio / HDMI
```
The Pi connects to the internet independently for providers. The mobile controller never needs a TCP/IP path. Existing loopback HTTP prototype is a local test fixture, not a mobile fallback. No LAN listeners, port forwarding, Cloudflare Tunnel routing or mDNS requirement for MVP. TV launcher may use a minimal loopback API or local IPC mediated by its trusted origin; choose isolation and prove that hostile websites cannot access privileged API/CDP. Prefer private Unix sockets/pipe for privileged IPC when supported, not unrestricted DevTools HTTP.

## Stack decisions
Rust stable pinned 1.100.0 observed; Tokio, Serde, thiserror, tracing; Axum only if needed for trusted local launcher HTTP (not an always-on mobile server). Linux Bluetooth: BlueZ D-Bus with BlueR (`bluer`) GATT server/advertising candidate; direct zbus adapter if justified, not both without need. Verify maintenance, dependency/feature footprint, package versions and privileges on actual target. Native iOS SwiftUI, CoreBluetooth, Swift Concurrency, Keychain, AVFoundation or VisionKit where supported; prefer native over a cross-platform wrapper for iOS-first BLE, conditional on spike. Chromium baseline, WPE research only. Wayland with Cage/labwc selection based on tests. React/TypeScript/Vite minimal static launcher; shadcn semantic tokens and selected primitives only when beneficial. SQLite conditional, atomic files for small trust/config store with restrictive modes and migration/backup. systemd/cgroups v2, journald, APT. No runtime Node on Pi. No extra daemon to supervise things systemd already handles.

## Dependency direction and process model
- Protocol: transport-independent types, version negotiation, bounds, command/result semantics. No BlueZ, Swift, Chromium or OS dependency. Shared schema and cross-language conformance fixtures.
- Core/application: validates manifests, authorized commands, capability negotiation, lifecycle state machine and event ordering. Depends on ports, not concrete drivers. No provider-specific logic.
- Platform adapters: BLE GATT, browser control, audio, diagnostics, persistence. Handle OS failures and translate typed errors. Only adapters access native OS facilities.
- Daemon composition root: wires concrete adapters, bounded Tokio tasks and graceful shutdown. Process supervisor (systemd) recovers daemon; daemon owns foreground app transitions, not a custom init system.
- Launcher: trusted local UI, not a security authority; never embeds untrusted sites with elevated privileges. Browser profile isolated from personal browsers; scope credentials carefully; do not allow arbitrary local/file/admin URLs.
- iOS app: native BLE adapter and authenticated session, protocol codecs, observable UI state; no duplicate domain rules or trusted capabilities inferred from app names.

Runtime state: stopped -> starting -> running -> stopping -> stopped; failures -> recovering -> running or failed/home. Serialize transitions in a bounded actor/state machine, no blocking operations in async executor, explicit timeouts and cancellation. Commands target current runtime generation; reject stale messages on app switch. Separate daemon and session/browser cgroups so browser failure does not kill control; test crash recovery and graceful process reaping. One foreground page/runtime. Browser can have multiple internal processes; no sandbox disabling or `--single-process` shortcut. Closing a page does not guarantee reclaim; measure and consider full process restart with persistent profile. Use capabilities observed at runtime, not merely manifest requests. Never log typed text, URLs with sensitive parameters, QR secrets, browser cookies or tokens.

## Proposed repo structure (create incrementally after approval)
```
pi-tv/
  Cargo.toml / Cargo.lock / rust-toolchain.toml
  crates/
    protocol/            # commands, events, versions, fixtures
    core/                # pure domain and use cases; ports
    daemon/              # composition and OS adapters as modules
      src/adapters/{ble,browser,platform,storage,local_ui}/
  apps/
    tv-launcher/         # React/TS, UI primitives, navigation
    ios-remote/          # SwiftUI Xcode project, CoreBluetooth
      Sources/{App,Features,DesignSystem,Transport,Protocol}/
      Tests/
  design/                # tokens, component specs, UX flows
  contracts/             # transport-neutral schemas, BLE profile, fixtures
  app-catalog/           # vetted JSON manifests, assets/licenses
  packaging/{debian,systemd,apt}/
  scripts/{dev,build,release}/
  benchmarks/            # lightweight sampling and scenarios
  tests/{contract,integration,hardware}/
  docs/{product,architecture,adr,security,design,feasibility,operations}/
  prototypes/            # disposable existing research, not prod dependency
  evidence/              # sanitized historical and reproducible evidence
  .github/workflows/
  AGENTS.md README.md LICENSE TRADEMARK_POLICY.md CONTRIBUTING.md SECURITY.md
```
Do not create empty speculative crates. Extract adapters into separate crates only when platform dependency isolation or reuse is demonstrated. Keep Rust workspace explicit, small, stable public interfaces. Production must not import prototype code. Document any deliberate deviations. Use dependency graph CI checks, lockfiles, format/lint, generated-code drift checks and tests. Avoid maintaining equivalent schemas in multiple languages by hand; prefer one canonical schema plus fixtures and deterministic code generation if proven beneficial.

## Host prerequisites and dev workflow
Actual Mac ARM64 macOS 27.2.1, Xcode 27.2 SDK, Swift 6.4.2, Rust 1.100.0 rustup in login shell, Node 26/pnpm 12 and Docker ARM64 builder reported. Check non-login shell resolution explicitly (use rustup run 1.100.0 cargo or deterministic PATH), available simulator, physical iPhone signing, Bluetooth permissions and macOS peripheral support; simulator install blocked previously. No new required tools until dependency review. Linux ARM64 build via pinned Debian 12 builder; actual Pi libc/BlueZ/package sources still need inspection. Build artifacts off-Pi. Pi Bluetooth service present; read-only `bluetoothctl show`, `bluetoothctl list`, `rfkill list`, `dpkg-query -W bluez`, `busctl introspect org.bluez /org/bluez/hci0` only when authorized; adapter path discover dynamically. Do not change rfkill, pairings, services or install packages on shared host without permission.

Proposed dev commands (`just` or equivalent): dev/mock, dev/macos-ble, test, lint, build-arm64, package-test, hardware-report. Use a fake transport in simulator and CI, Mac CoreBluetooth peripheral or separately authorized Linux BLE test rig for physical iPhone spike. A successful Mac BLE test is not BlueZ hardware evidence. Actual Pi BLE test can run without HDMI using test-only QR displayed on Mac, provided owner authorizes Pi access and deployment. Production on-TV enrollment and recovery must be tested with HDMI later.
