# Lightweight Entertainment Platform — Product & Engineering Requirements

**Version:** 0.1 — proposed baseline for approval and feasibility validation
**Date:** 27 November 2026
**Working name:** PiTV (not a cleared product name)
**Primary target:** Raspberry Pi 4 Model B, 1 GB physical RAM; modern iPhone
**Status:** architecture remains proposed; host-first feasibility prototype is partial; Raspberry Pi hardware, DRM and secure native transport gates remain open

## 1. Product intent

Build a lightweight, local-first, extensible Linux entertainment appliance that converts an HDMI television into a remotely controlled entertainment display. The appliance executes media locally; the phone is a controller, not a streaming relay. Users install a package or, later, flash a supported image, connect HDMI and network, pair an iPhone, launch applications and control them without requiring a project-owned cloud service. External providers may require internet, subscriptions, login, DRM and their own terms.

The user explicitly requires Pi 4B 1 GB, modern iOS, performance, maintainability, distribution simplicity and provider independence. Prior discussion supports Rust, native packaging and a single foreground runtime; exact dependencies and numerical targets below remain proposals until validated. Android is a future client, not an MVP release requirement. Assume a dedicated appliance for certification; existing unrelated services are not modified and concurrent workloads are not certified by default.

### Success and non-goals

Success means a reproducible install on the actual 1 GB device, responsive remote during sustained playback, safe pairing, recoverable failures, persistent provider sessions, and the ability to add a second provider without modifying core logic. This is not a certified Android TV, Google Cast receiver, AirPlay receiver, streaming subscription reseller, browser engine, DRM implementation, or cloud service. No claims of universal streaming, 4K streaming, official provider certification or DRM resolution guarantees. No arbitrary native executable marketplace, multi-window playback, remote internet access, mirroring, background music or self-updating browser in MVP.

## 2. Requirements and scope

| ID | Priority | Requirement / acceptance |
|---|---|---|
| F-01 | P0 | Boot into a usable HDMI launcher after provisioning; no keyboard needed in normal operation; display actionable recovery instructions. |
| F-02 | P0 | Local iOS onboarding: discover via Bonjour, scan on-TV QR, authenticate identity and pair; manual address fallback; clear permission and network errors. |
| F-03 | P0 | Native iOS remote: Home, Back, pointer/touchpad, click, scroll, keyboard/text, directional navigation where supported, system volume/mute; visible connection and foreground app state. |
| F-04 | P0 | Generic app catalog, launch/close/restart; versioned manifest; add approved web app without Rust or mobile code changes; no provider-specific core logic. |
| F-05 | P0 | Single active media application; release previous runtime resources; preserve permitted provider login data across restarts; no project collection of provider credentials. |
| F-06 | P0 | Play/pause/seek/next only when available; generic input fallback. Unsupported actions return explicit capability errors. No fake playback state. |
| F-07 | P0 | Remote disconnect and screen lock do not interrupt playback; reconnect restores authoritative state without replaying stale commands. |
| F-08 | P0 | Unprivileged core, local transport authentication, revoke paired devices, rotate/reset identity only through deliberate local action; protect secrets and provider profiles. |
| F-09 | P0 | Recovery from browser failure, service restart, network change, HDMI reconnect; bounded restart loops and clear diagnostics. |
| F-10 | P0 | Install/uninstall/upgrade a versioned ARM64 Debian package on supported OS, preserve configuration and credentials on normal upgrades, explicitly separate purge/reset. |
| F-11 | P0 | YouTube, Netflix, Spotify, Jellyfin feasibility matrix; each provider status and limitation visible, only verified apps advertised as supported. |
| F-12 | P1 | User-approved custom HTTPS web app catalog entry; validated URL, safe icon handling and separate app metadata; no remote script injection. |
| F-13 | P1 | Secure browser remote (only after browser trust onboarding works); do not present insecure HTTP as production substitute. |
| F-14 | P1 | Signed APT repo, recovery tooling, reproducible image recipe and image artifact. Package is source of truth for OS image. |
| F-15 | P1 | iOS distribution through TestFlight then App Store, following review requirements; multi-device saved pairings; accessibility and localization. |
| F-16 | P2 | Android remote, native media via MPV, HDMI-CEC, optional background audio, other boards/OS architectures; separately gated. |

P0 denotes required MVP behavior, not a declaration of existing implementation. App Store release and public package distribution require their own security, licensing, and hardware gates. Phase 0 must test all four reference providers. Proposed first release needs at least two distinct validated services (video plus another provider, ideally audio) and no provider-specific core modifications. If Netflix cannot work lawfully or reliably on the device, mark unsupported and obtain product-owner approval for a limited release; if Netflix is a mandatory product outcome, hold release. Never silently relax the 1 GB constraint.

## 3. Hardware and compatibility policy

- Reference hardware: Pi 4B 1 GB (not a 2/4 GB board constrained by cgroups as a substitute). Reference OS: supported Raspberry Pi OS Lite ARM64, exact image date/version and packages recorded. Existing Debian is a comparison target, not initially guaranteed. Preserve existing installation; use spare media or backup and explicit consent for destructive operations.
- Single HDMI display, default target output 1080p, configurable 720p output for performance comparison; HDMI audio; Ethernet baseline, Wi-Fi separately tested. A 1080p display output does not imply 1080p video decoding. No overclock, no disabled browser sandbox, no unsupported graphics flags in certified defaults.
- Pi 4 advertises H.264 1080p60 and H.265 4K60 decode. VP9/AV1 hardware decoding is not advertised. Actual accelerated decoding depends on kernel, Mesa, browser, codec and compositing; measure rather than infer. Compare with real provider content without bypassing DRM.
- iOS: proposed minimum iOS 18, test current generally available iOS and minimum supported OS on real hardware where obtainable. Validate chosen framework's actual deployment target; user has not supplied exact iPhone/OS. SDK used for submission is distinct from minimum deployment version. Follow current Apple submission and Xcode compatibility requirements when locking toolchain.
- Support matrix keys: device RAM, OS image, kernel, browser/DRM package, compositor, provider, resolution, codec where observable, login, audio, fullscreen, input, stability, test date. Status: verified / degraded / unsupported / untested; no fabricated data. Use licensed accounts supplied by owner for interactive tests; no credentials in repo/CI logs.

## 4. Architecture decisions and trade-offs

| Area | Proposed baseline | Rationale / reconsideration trigger |
|---|---|---|
| Core | Rust stable; Tokio, Axum, Serde, tracing; minimal features | Resource control and safe ownership, not a guarantee of lower system RAM. If spike misses budget, profile first; Go is fallback only via ADR and owner approval. |
| Architecture | One daemon, modular monolith, separate compositor/browser processes | Independent recovery; avoid distributed systems and excessive crate count. |
| Display | labwc or Cage over Wayland, selected by Pi tests | Existing compositor; direct DRM/KMS/custom compositor not MVP. |
| Media | OS-packaged Chromium first; WPE WebKit optional experiment | Browser/DRM compatibility outweighs theoretical memory gains; WPE only if material measured gain without losing required features. |
| Browser control | Small internal CDP adapter plus generic input; MPRIS when available | CDP has no backward compatibility guarantee; use bounded documented subset, smoke test on upgrades. No provider DOM selectors, arbitrary JavaScript API or raw CDP exposed to phone. |
| Launcher | React + TypeScript + Vite, static assets, strict bundle budgets | Consistent ecosystem; vanilla TS fallback if measured launcher overhead fails budget. No Node runtime on Pi. |
| Mobile | SwiftUI is now a host-first feasibility candidate; React Native + Expo remains an alternative | iOS is the primary mobile target. A native spike covers Bonjour, WSS certificate pinning and Keychain; simulator build and physical-device behavior must pass before selection. React Native remains useful if Android is approved and its native networking/trust module burden is acceptable. This is not a ratified ADR. |
| Transport | Versioned HTTPS/WSS, JSON | Interoperable; standard TLS, bounded protocol. No custom crypto. |
| Persistence | Atomic files with serialized writer for small state, restrictive permissions | SQLite when transactional/query requirements justify; migrations and crash safety either way. |
| Discovery | Avahi + Bonjour | Standard discovery; untrusted hints, never authentication. |
| Host mode | Shared Host by default on the reference Pi; separate systemd units and a dedicated resource isolation boundary | Preserve Vaultwarden, Telegram Media Downloader, Cloudflare Tunnel, Docker/containerd and host services. Evaluate cgroup controls before setting production limits. |
| Diagnostics | Capability-based probes with graceful fallback | PSI may be absent; report unavailable signals without failing startup or inventing values. |
| Network exposure | Configurable listener ports with startup conflict detection | Never expose browser debugging or unauthenticated control endpoints to LAN or Cloudflare Tunnel; no WAN listener or port forwarding. |
| Privileged actions | Shutdown disabled by default in Shared Host mode | Keep host shutdown authority out of the entertainment service unless a later owner-approved mode and narrow authorization justify it. |
| System | systemd, journald, cgroups v2; ALSA/PipeWire based on tested stack | Reuse OS facilities, no custom general-purpose supervisor or governor. Do not change kernel, swap, system services or firewall without explicit approval. |
| Swap | No production dependency on swap capacity; evaluate ZRAM only through comparative benchmarks | Swap does not replace physical memory. Do not change swap configuration without explicit approval. |
| Packaging | Cargo release, ARM64 .deb, apt; later rpi-image-gen | OS-managed dependencies/security updates, no custom package manager. |

### Process/trust boundaries

```
iPhone (remote, keychain) -- TLS/WSS --> unprivileged device daemon
                                        | app catalog, pairing, commands, state
                                        | local-only IPC / restricted controller
                                        v
                                isolated graphical user/session
                                  compositor -> one browser -> HDMI/audio
                                                | external provider HTTPS
                                        (no remote API secrets in provider pages)
```

The entertainment platform runs in separate systemd units and a dedicated resource isolation boundary. All network listening ports are configurable and checked for conflicts at startup. Browser debugging remains private to the isolated local session and is never bound to a LAN or tunnel interface; unauthenticated control endpoints are never exposed to LAN or Cloudflare Tunnel. Shared Host mode has no host shutdown capability by default.

The daemon owns desired foreground app/session and command serialization, systemd owns process restart and service/cgroup supervision. Use a dedicated graphical user and correctly provision seat/DRM/input/audio via supported session mechanisms. No blanket root, no world-writable input devices; narrow authorization for optional privileged actions; shutdown may be deferred if safe authorization not ready. Core startup must not require internet. Browser crash must not terminate core. Ensure actual process-tree accounting/cleanup and do not rely on PID name killing.

Core modules: domain (app ID/capability/session/state), application (use cases and lifecycle), transport (HTTP/WSS), adapters (Linux/systemd, browser, storage, discovery, audio). Ports only for genuine boundaries. Mock adapters must support contract and failure tests. Avoid a crate per feature; start with core/protocol and daemon/CLI only where justified. Runtime adapter exposes launch, stop, state, capabilities, dispatch, health and cleanup; no raw CDP crossing boundary. Capability discovery reports supported/unknown/unavailable based on actual state, not just manifest wishes. New native runtime may require platform work but must not change universal command vocabulary unnecessarily.

### Application lifecycle and launcher

One foreground runtime, no hidden media tabs or multiple browser instances by default. Navigate/reuse one profile as validated; close unwanted popups/tabs with a policy that does not break provider login. Release old page; measure whether renderers, caches and audio actually release memory. If reuse leaks, restart browser at app switch with persistent profile and bounded recovery, not during active playback. Never clear cookies/profile as memory-pressure mitigation. Browser startup/recovery has deadline, backoff, failure state and local escape/home mechanism independent of provider UI. Use controlled loopback launcher origin, read-only/static or narrowly scoped launcher actions with strict Origin/Host/CSRF protections; remote secrets never exposed to external pages. Test DNS rebinding, cross-origin and local network abuse. No third-party app content embedded with privileged JS bridges.

## 5. Protocol and application model

HTTP `/api/v1`: capabilities, device state, approved catalog, pairing, token revocation, diagnostics (authorized and redacted). WSS `/api/v1/events`: authenticated handshake, command/ack/state event, explicit protocol version. Use request IDs, per-connection sequence/state revision, deadlines, bounded queues and payload sizes, connection limit, timeouts and heartbeat; throttle/coalesce pointer moves only, preserve ordered clicks/keys, release held keys on disconnect; no stale command replay on reconnect. Distinguish accepted vs applied vs failed; remote does not claim successful provider action without evidence. Snapshot on reconnect, handle duplicates and version mismatch with actionable error. Define schemas and generate/test client types; no executable JSON. Set initial limits via ADR and verify burst/slow-client behavior.

Example manifest (illustrative, not provider certification):

```json
{
  "schema_version": 1,
  "id": "netflix",
  "name": "Netflix",
  "runtime": "web",
  "entrypoint": "https://www.netflix.com/",
  "requirements": {"internet": true, "drm": ["widevine"]},
  "requested_capabilities": ["input.pointer", "input.keyboard", "media.play_pause"],
  "session": {"persistent": true}
}
```

Manifest validation: strict version and ID, URL scheme/host rules, no executable commands or injected JS; vetted bundled entries initially; local custom app support only with explicit approval. Permit legitimate provider login redirects with documented safe policy. No arbitrary `file:`, `javascript:`, browser-internal or local administrative endpoints; separate explicitly configured local media integrations from public URL input. Icons bundled or retrieved with bounded, safe policy; avoid server-side arbitrary fetch/SSRF. Brand assets require licensing review. Manifest requests are intersected with runtime/device permissions and actual capability. Standard commands: `app.launch`, `app.close`, `app.restart`, `input.key`, `input.text`, `input.pointer.move`, `input.pointer.click`, `input.scroll`, `media.play`, `media.pause`, `media.seek`, `media.next`, `system.home`, `system.volume.set`, `system.volume.mute`. MPRIS/media session optional; generic input fallback; no provider-specific API required for initial implementation.

## 6. Security and iOS networking

LAN is untrusted. Device generates unique TLS identity and private key on first boot (never shared in an image); private key restrictive permissions. QR displayed on TV includes endpoint/device ID, fingerprint of authenticated public key/certificate and short-lived high-entropy one-use pairing secret. Client checks TLS identity against QR trust anchor before transmitting pairing secret; verified TLS on every reconnect; keychain stores identity and revocable credential. Pairing expires, rate-limited, replay-resistant, visible on TV; optional local confirmation. Manual address discovery does not waive identity verification; fallback must preserve equivalent authenticated pairing. Never trust arbitrary self-signed certs, disable hostname/trust globally, use broad ATS exceptions or HTTP tokens. A native security spike must prove trust handling on iOS (including changed IP and wrong cert), appropriate local-network ATS policy, TLS verification semantics and WSS using same trust policy. Cert/key rotation requires authenticated rotation or re-pairing; identity reset explicitly invalidates old tokens. Use standard TLS implementation (rustls if selected), no homegrown encryption.

Bonjour `NSLocalNetworkUsageDescription` and `NSBonjourServices` (e.g. `_pitv._tcp` chosen working service type); explain permission denial/settings recovery. Test on physical iPhone, not simulator alone. Do not depend on iOS background WebSocket execution; reconnect on foreground. Manual discovery fallback covers AP isolation/mDNS failure when direct connectivity exists; cannot overcome network segmentation. No WAN listeners/port forwarding/UPnP; restrict bind/firewall as appropriate. Validate WebSocket Origin for browser clients, auth every control, CSRF protection where applicable, bounded request bodies/rate limits, no shell execution from commands. Browser CDP restricted to local private IPC or loopback with isolation from untrusted pages/processes, no LAN exposure; assess loopback attacks explicitly; browser sandbox stays enabled. Secrets, typed text, credentials, QR secrets, session cookies and provider playback histories never logged. Diagnostic exports redacted. Review license/SBOM, dependency advisories, supply-chain signing, provider terms and App Store policies before public distribution.

Browser web remote is deferred until trusted HTTPS onboarding can work on Safari/other browsers without installing a globally trusted CA casually or bypassing certificate warnings; native QR-pinned trust does not automatically extend to browser clients. No requirement to use cloud for this. If no usable secure method exists, leave web remote optional.

## 7. Performance requirements — initial engineering targets

These are proposed acceptance targets, not measured facts. On actual 1 GB hardware measure Linux `MemAvailable`, PSS, cgroup memory.current/peak/events, memory PSI, swap activity, CPU per core, temperature/throttling and frame counters; no summing RSS across Chromium workers. Use OS-reported physical available RAM rather than nominal 1024 MiB. Record measurement intervals, OS baseline, network conditions, content/codec and methodology. Avoid intrusive profiling during final playback tests.

| Metric | Initial target / gate |
|---|---|
| Core idle PSS | <=20 MiB (investigate if exceeded) |
| Core idle CPU | <=1% of one logical core averaged over 5 min |
| Whole-system headroom | MemAvailable >=100 MiB at >=95% of 5s samples during steady playback; report minima and pressure events; no sustained severe pressure |
| OOM | Zero OOM kills, no unexpected restarts, no persistent swap-in/out during stable playback |
| Launcher assets | <=200 KiB compressed initial JS (proposed); no remote fonts, video backgrounds, heavy animation |
| Playback floor | 720p30 stable for supported video reference path; 1080p30 stretch only if measured; 1080p60 optional |
| Dropped frames | <1% steady-state where observable, excluding documented warmup; no recurring stutter/audio underruns; report unavailable metrics as such |
| Remote latency | p95 <=100 ms command round trip/ack on controlled LAN during playback; separately measure visible action when observable; report sample size |
| Boot | <=45 s cold boot to usable launcher on reference storage, proposed |
| Switching | no unbounded renderer growth over 30 app-switch cycles; return to launcher within proposed 5s on normal conditions, report provider page readiness separately |
| Soak | 2 h per candidate provider before selection; 24 h integrated session including reconnect/switch; 72 h release reliability run on actual Pi |
| Thermal | no undervoltage/throttling in reference conditions; record ambient/cooling/power supply |
| Regression | <=10% growth from validated baseline for core memory/CPU and latency, or explicit ADR and new benchmark; hard release gates still apply |

Compare vanilla launcher vs React only if budget fails; compare labwc/Cage, supported Chromium variants and WPE only where viable. ARM64 preferred for support; 32-bit experiment only with documented compatibility/security/DRM trade-off, not automatic production fallback. Evaluate ZRAM only in a controlled comparison against the existing swap setup; do not treat swap capacity as physical memory. Do not disable security updates, sandbox, TLS, GPU acceleration or integrity checks for a benchmark. Use cgroups for accounting and selective resource control; evaluate MemoryHigh/MemoryMax before recommending production limits; no arbitrary low browser cap that kills playback. Measure playback concurrently with representative workloads from existing services. Reduce scope, display resolution, browser overhead or provider certification if targets fail; 1 GB hardware cannot be silently changed.

## 8. Distribution, updates and operations

Build on development host/CI, not production Pi. ARM64 native Linux builder or matching Debian sysroot cross-build; verify glibc/ABI and runtime dependencies on real target. Rust toolchain pin, Cargo.lock, JS lockfile, pinned OS build inputs; avoid freezing browser security patches indefinitely. `dpkg-deb`, lintian, package scripts tested clean install, upgrade, removal, reinstall and interrupted update; package must not overwrite user's network/boot config or remove unrelated services. Use dedicated data/config paths, owner/mode policies, atomic file writes (temp+fsync+rename and directory sync when required), backup before schema changes, rollback-compatible schema or documented restore. systemd logs bounded; no constant disk churn. Public APT repo signed Release metadata with per-repo keyring, signed/checksummed images and artifacts; no curl-to-root installer or broad trust. APT rollback is not automatic: preserve last compatible package/config backup and recovery docs; OS A/B updates not MVP. Image builds from same .deb, no cloned credentials; first-boot provision via supported OS mechanism. Publish source/license, third-party notices and DRM licensing decision; no redistribution of proprietary CDM absent permission. Test HDMI headless recovery, power cycling, limited disk and network failures.

## 9. Engineering and testing governance

Monorepo suggestion: `crates/{core,protocol,daemon}`, `apps/{launcher,ios-remote}`, `contracts/`, `packaging/`, `benchmarks/`, `tests/`, `docs/`, `AGENTS.md`. Add modules only when justified. No scaffolding for speculative runtimes/services. Rust fmt/Clippy, tests, safe Rust default, explicit FFI audit, cargo-deny/audit, TypeScript strict, lint and unit tests, Playwright launcher/contract tests, real iOS tests and Pi hardware rig. Pin toolchains, automate dependency updates with review, generate SBOM and license reports, explicit vulnerability policy and exceptions with expiry. CI: host checks, ARM64 build/package tests, protocol conformance, mock runtime tests, iOS build on macOS, physical hardware report for release. Use bounded command/property/fuzz tests where appropriate. No fake benchmark, no claimed passing if hardware/accounts missing. Record commands, versions, raw evidence, failures and skipped tests; never log secrets. Maintain ADR for every significant boundary/dependency choice; avoid custom infra and premature optimization. Test browser updates on certified matrix; block incompatible release combinations but keep security update path. Agent must not weaken guardrails to pass tests. Developer review required for security, pairing, privileged code, packaging and release.

## 10. Delivery phases and exit gates

| Phase | Output | Gate |
|---|---|---|
| 0 — feasibility | Non-destructive host inventory, benchmark harness, minimal browser/compositor spike, reference provider matrix, iOS TLS/discovery spike, ADR candidates | Actual Pi 4B 1 GB evidence; physical iPhone trust/permission evidence; shared-host isolation and concurrent workload results; blockers explicitly reported. No full app yet. |
| 1 — architecture baseline | Ratified PRD, contracts, threat model, dependency policy, AGENTS.md, minimal CI | Owner reviews feasibility and scope; lock supported baseline and performance gates. |
| 2 — core vertical slice | Minimal daemon + mock/runtime adapter + launcher + one remote command | Secure transport, recovery, bounded state and measured overhead. |
| 3 — universal remote/catalog | iOS pairing, touchpad, keyboard, state reconnect, media capability, multi-provider manifests | Real iPhone and Pi integration, no provider code in core. |
| 4 — hardening and packaging | .deb install/upgrade/uninstall, recovery, resource/security regression, 24/72h tests | Physical evidence and security/operational release gate. |
| 5 — public distribution | Signed APT, TestFlight/App Store, optional image; web remote if secure | Review current store SDK, licensing, signing, release docs. |
| 6 — extensions | Android, alternate hardware/runtime, native media, HDMI-CEC | Independent ADR and hardware gates; no regressions to 1 GB. |

Phase 0 report at `PHASE0_FEASIBILITY.md` distinguishes verified observations, proposals, assumptions and untested gates. It must distinguish PASS / FAIL / BLOCKED / NOT RUN, summarize actual observed provider resolution and DRM, and recommend one baseline. If mandatory capabilities cannot meet hardware budget, stop and request a product trade-off rather than generating architecture around untested assumptions. Full product implementation remains gated on owner approval of the Phase 0 review.

## 11. Open decisions / explicit owner review

Minimum iOS 18, release scope/two-provider rule, 720p floor, memory/latency limits, choice of native iOS framework and first public distribution model remain proposals, not approvals. Product name and license (including third-party obligations) are unsettled. Netflix/Spotify DRM and distribution feasibility, secure local iOS transport, display mode, hardware decode, and 1 GB playback remain unverified. Candidate ADRs: Shared Host isolation and cgroup policy; capability-based diagnostics without PSI; configurable listener ports and conflict handling; private browser debugging and no unauthenticated control exposure; shutdown disabled by default; controlled ZRAM evaluation and concurrency benchmarks. See `PHASE0_FEASIBILITY.md`; no full product implementation is authorized before the Phase 0 review gate.

## 12. Reference documentation (checked 27 Nov 2026; recheck before pinning)

- Raspberry Pi hardware: https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/
- OS images: https://www.raspberrypi.com/software/operating-systems/
- Kiosk guide (desktop-based reference, not proof of Lite playback): https://www.raspberrypi.com/tutorials/how-to-use-a-raspberry-pi-in-kiosk-mode/
- Netflix supported browsers: https://help.netflix.com/en/node/30081
- Spotify web player: https://support.spotify.com/ws/article/web-player-help/
- Rust targets: https://doc.rust-lang.org/stable/rustc/platform-support.html
- CDP compatibility: https://chromedevtools.github.io/devtools-protocol/
- systemd resource control: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- Apple local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- Apple ATS: https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- Apple manual trust: https://developer.apple.com/documentation/foundation/performing-manual-server-trust-authentication
- Xcode compatibility: https://developer.apple.com/xcode/system-requirements/
- App Store submitting: https://developer.apple.com/app-store/submitting/
- App Review: https://developer.apple.com/app-store/review/guidelines/
- Expo development builds: https://docs.expo.dev/develop/development-builds/introduction/
- Expo SDK compatibility: https://docs.expo.dev/versions/latest/

## 13. Host-first feasibility update — 27 November 2026

The owner authorized initial development and feasibility testing on Apple Silicon macOS without requiring the Pi or HDMI connection. This changes the development sequence only. Raspberry Pi 4 Model B with 1 GB physical RAM remains mandatory production hardware; macOS results do not establish Pi performance, playback, hardware decoding, DRM, Linux ABI compatibility, or display behavior.

A disposable host-first prototype now demonstrates a manifest-driven ten-foot launcher, macOS Chrome lifecycle adapter, loopback-only HTTP/WebSocket command interface, capability report, and native Swift networking/security source spike. The daemon also builds as an AArch64 Linux ELF in a Debian 12 ARM64 container; the actual Pi OS/runtime has not been validated. Browser checks are limited to public landing-page navigation and generic input. No authenticated pairing, provider playback or DRM was demonstrated. The source, run records, limitations, risk register, and reproducible commands are in `PHASE0B_HOST_FIRST_REPORT.md`, `PHASE0B_PACKAGE_REPORT.md`, `PHASE0B_RISK_REGISTER.md`, and `PHASE0_FEASIBILITY.md`.

The native-vs-cross-platform mobile choice, runtime adapters, and protocol remain candidate ADRs. The prototype intentionally omits a production pairing UX, server identity provisioning, remote-control feature set, distribution signing, Linux runtime adapter, and product hardening. Phase 0 approval and production implementation remain blocked on owner review of the feasibility evidence and actual target hardware gates.
