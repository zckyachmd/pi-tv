# Phase 0B host-first feasibility report

**Disposition:** Host-first development is feasible for the disposable launcher/runtime/control prototype. The daemon now builds as an AArch64 Linux ELF in a pinned Debian 12 environment, but it has not been executed against the actual Raspberry Pi OS or hardware. No Raspberry Pi playback, provider authentication/playback, DRM support, or secure phone-to-Pi pairing has been demonstrated. Phase 0 remains open; candidate ADRs below are proposals only.

See [`PHASE0B_RISK_REGISTER.md`](PHASE0B_RISK_REGISTER.md) for the evidence-based open risk list and owner actions.

## Verified development host

Checks run from a login shell so the repository's `rust-toolchain.toml` selects rustup:

| Component | Observation | Status |
|---|---|---|
| Host | Apple Silicon macOS 27.2.1 | Verified |
| Rust | rustc/Cargo 1.100.0, pinned by repository `rust-toolchain.toml`; ARM64 Linux target installed | Verified in login shell |
| Xcode / SDK | Xcode 27.2 (27B52), iPhoneOS SDK 27.2; iOS 27.2 simulator runtime available | Verified present |
| Swift | Swift 6.4.2 | Verified present |
| JavaScript | Node 26.13.1, npm 11.20.0, pnpm 12.21.0 | Verified present |
| Browser | Google Chrome 158.0.8127.37 at the standard macOS app path | Verified present; no Chromium app found |

The repository pins Rust 1.100.0. Login-shell resolution was checked and uses that rustup toolchain. Non-login command environments have previously resolved Homebrew Rust; use the explicit login-shell commands below until PATH behavior is consistent across shells. This is a resolution issue, not evidence that the Linux target cannot be built.

## Disposable Rust daemon and simulated TV

[`prototypes/host-first/daemon/`](prototypes/host-first/daemon/) contains a small Tokio/Axum daemon with a `RuntimeAdapter` boundary and a macOS Chrome adapter. It parses the static app manifest, validates version, duplicate IDs, and web/local-relative URL forms, then dispatches allowlisted launch/home/stop commands over HTTP or WebSocket. It reports runtime capabilities and returns structured command errors. The HTTP listener binds only to `127.0.0.1`; state-changing HTTP and WebSocket requests require a matching local Origin. Logs use JSON tracing and omit URLs and typed content.

The Chrome adapter uses one dedicated profile and process group, launches kiosk mode, and terminates its previous process group before switching. It does not enable remote debugging. The separate browser smoke harness tested DevTools only on a fresh Chrome profile bound to loopback, and terminated it after the test. Neither path is approved for LAN use or production pairing.

[`prototypes/host-first/web/`](prototypes/host-first/web/) is a deliberately plain ten-foot test fixture: manifest-driven app focus, D-pad/Enter, fullscreen request, text entry, pointer, and scrolling. The UI smoke shows browser navigation to generic, YouTube, Netflix and Spotify public landing pages. No provider login or playback was attempted.

Rust validation commands and result:

```sh
zsh -lc 'cargo fmt --manifest-path prototypes/host-first/daemon/Cargo.toml --check'
zsh -lc 'cargo test --manifest-path prototypes/host-first/daemon/Cargo.toml --locked --offline'
zsh -lc 'cargo clippy --manifest-path prototypes/host-first/daemon/Cargo.toml --locked --offline -- -D warnings'
```

The manifest-validation and local WebSocket command-dispatch tests pass; Clippy passes with warnings denied. A live local HTTP smoke switched Chrome between the app manifest entry, launcher, and stop action, rejected a mismatched Origin with 403, and shut down the temporary browser profile. Sanitized details are recorded in `evidence/phase0b/host-first/`.

## Browser runtime observations

See [`evidence/phase0b/browser/runtime-smoke.json`](evidence/phase0b/browser/runtime-smoke.json). The run uses an isolated temporary Chrome profile and a temporary loopback-only HTTP fixture. It records startup/termination, one page target, private loopback CDP connectivity, D-pad movement, text insertion, pointer click, wheel scrolling, fullscreen API, public landing-page navigation, profile persistence, crash/kill/relaunch, and generic media controls. Only each recorded `VERIFIED` field is a pass. Media-key mapping and seek remain unverified; macOS fullscreen behavior is not HDMI/display-mode validation.

Provider navigation proves only that public landing pages loaded in that host browser during the run. It says nothing about login, entitlement, DRM, video playback or Raspberry Pi support.

## iOS framework feasibility

[`prototypes/host-first/ios-swift/`](prototypes/host-first/ios-swift/) is a small native spike with a minimal SwiftUI device-list view and APIs for Bonjour browsing, WSS with a QR-provisioned certificate pin, bearer-token transport, and Keychain storage. The Swift library and app shell in `prototypes/host-first/ios-app/` compile for iOS Simulator 27.2. The latest run built the app but **BLOCKED** at simulator install: `simctl install` timed out. The simulator was shut down afterward. No successful app launch is claimed. Bonjour permission UX, pairing, QR scanning, certificate rotation, wrong-device rejection at runtime, and physical iPhone behavior remain unverified.

SwiftUI is the smaller first-client candidate because the product is iOS-first and the security-sensitive APIs are native. React Native remains viable if Android becomes an approved delivery requirement; current Node/pnpm/Xcode are present, but no React Native project was built. As checked against official docs, React Native's current environment guide calls for Node 22.11+ and current Xcode, the current Expo SDK table requires Xcode 26.4+ for its supported SDKs, and pnpm 12 supports Node 26 on macOS ARM64; the observed host versions meet these tool baselines. The Expo Go path is not sufficient for validating custom native trust and Bonjour behavior; use a development build if that option is selected. This comparison is not an ADR ratification.

Official compatibility and API references: [React Native environment setup](https://reactnative.dev/docs/set-up-your-environment), [Expo SDK compatibility](https://docs.expo.dev/versions/latest/), [pnpm installation and supported platforms](https://pnpm.io/installation), [Apple NWBrowser](https://developer.apple.com/documentation/network/nwbrowser), [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask), and [SecTrustEvaluateWithError](https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A%29?changes=l__6&language=objc). Recheck version tables when the prototype toolchain is pinned for implementation.

## Development workflow proposal

The working commands use only the development Mac. They do not configure or mutate a Pi:

```sh
# 1. Start the local host-first daemon and its kiosk browser/profile
scripts/phase0b/run-host-first.sh

# 2. Check the local health and app catalog in a second terminal
curl --fail http://127.0.0.1:8765/api/v1/health
curl --fail http://127.0.0.1:8765/api/v1/apps

# 3. Run the disposable browser behavior harness
node scripts/phase0b/chrome-runtime-smoke.mjs

# 4. Run the iOS Simulator SDK compile check
IOS_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --package-path prototypes/host-first/ios-swift \
  --triple arm64-apple-ios27.2-simulator --sdk "$IOS_SDK"

# Build, install and launch the SwiftUI shell on an available iPhone Simulator
python3 scripts/phase0b/ios-simulator-smoke.py

# 5. Cross-build smoke artifact in the digest-pinned Debian 12 ARM64 builder
scripts/phase0b/build-arm64-smoke.sh

# 6. Build and inspect the locked disposable daemon for Debian 12 ARM64
scripts/phase0b/build-host-first-arm64.sh

# Run the Rust, iOS SDK and browser checks in one command
scripts/phase0b/host-first-checks.sh
```

For repeatable local validation, run `cargo test` and `cargo clippy` commands above. The daemon starts the launcher itself; selecting an app switches the foreground Chrome process. The iOS simulator command is reproducible but currently blocked at install by a Simulator service timeout. The account profile path is disposable and should not contain personal browsing credentials. Do not point this prototype at a real Chrome profile.

The ARM64 workflow builds both the dependency-free Rust smoke binary and this disposable daemon in the digest-pinned Debian 12 ARM64 environment; see `PHASE0B_BUILD_REPORT.md` and `evidence/phase0b/host-first/arm64-build-metadata.json`. ELF and dynamic dependency inspection does not verify the actual Raspberry Pi OS image or target execution. Future deployment commands must wait for target OS/package-source review, recovery plan, owner authorization and install/upgrade/uninstall validation. Keep builders and package managers off the production Pi.

## Candidate ADRs for investigation, not ratification

| Candidate | Evidence and remaining question |
|---|---|
| ADR-C08 — Host-first development adapters | The macOS Chrome adapter and Linux AArch64 daemon build show a viable development split; Linux desktop/browser runtime behavior and Pi execution remain untested. Keep runtime operations behind the small trait; avoid encoding macOS behavior into the core. |
| ADR-C09 — Client-independent protocol | HTTP/JSON and WebSocket command forms compile, and WebSocket dispatch passes against a mock runtime. Authentication, compatibility/version policy, limits, LAN transport and real iOS interoperability remain untested. |
| ADR-C10 — Native iOS vs React Native | SwiftUI and native Bonjour/WSS/Keychain sources compile against the iOS Simulator SDK. React Native remains an option if an approved Android roadmap justifies a native-module layer. Verify runtime behavior on simulator and physical phone before ratifying. |
| ADR-C11 — Browser runtime | Host Chrome supports the tested generic navigation/input path; media key/fullscreen checks are partial and public landing pages do not validate provider access. Compare target Chromium/Cage or labwc only after Pi/display authorization. |

## Explicitly deferred Phase 0 gates

No Pi was accessed or mutated. Raspberry Pi OS package sources and installed package baseline, cgroup/systemd limits, current services and port ownership, GPU/decoder nodes, HDMI modes, non-root display session, Chromium/compositor baseline, actual accelerated decode, provider DRM, concurrent workloads, memory/CPU/I/O/thermal behavior, physical iPhone permissions/trust, and secured local pairing remain blocked or not run. Do not infer any of those results from macOS.

## Owner actions to unblock Phase 0C

1. Approve the Phase 0 feasibility review and a read-only access path to the actual Pi 4B 1 GB; provide the target OS/image version and an independent recovery route.
2. Provide a connected HDMI display and confirm the intended display mode, audio path, power supply and cooling before the graphical-session gate.
3. Review the Debian package plans against the target's actual configured repositories and available disk space. Give separate explicit authorization before any Pi package installation or other host mutation; none is authorized by this report.
4. Approve a scheduled, supervised Phase 0C test window, representative existing-service workloads, and the proposed abort thresholds in [`PHASE0C_BENCHMARK_PROTOCOL.md`](PHASE0C_BENCHMARK_PROTOCOL.md).
5. Where provider playback tests are approved, make legitimate test accounts/content available for manual sign-in. No account data should be placed in the repository or diagnostics.
6. Provide a physical iPhone and selected iOS version for Bonjour permission, QR pairing, authenticated WSS, identity mismatch and reconnect tests; simulator compilation is not a substitute.

No owner action above changes the product's 1 GB target or ratifies an ADR. Do not change host services, firewall, kernel, swap, or packages without separate explicit authorization.
