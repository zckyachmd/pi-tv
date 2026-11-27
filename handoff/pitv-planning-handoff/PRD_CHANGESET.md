# PRD change proposal — Bluetooth-first Pi TV

## Intent and authority
Keep existing PRD and historical reports; this changeset supersedes conflicting **proposals only after ratification**. Codex must reconcile every conflicting requirement, architecture table, threat model, protocol, test, prerequisite and roadmap (including old Bonjour/WSS/mobile listener assumptions). Preserve earlier decisions as superseded ADRs rather than rewriting test history.

## Product
A lightweight, local-first, provider-agnostic Linux entertainment appliance, operated by an iPhone over Bluetooth without a shared IP network. Pi streams its own content over Ethernet or Wi-Fi if needed; the phone sends commands, not video. A remote works with Wi-Fi/cellular disabled on the phone and with Pi networking disconnected for offline/local UI functions. Online media still needs internet. No cloud account for Pi TV. Target Pi 4 Model B Rev 1.1 / 1 GB physical RAM ARM64; existing Bookworm shared host and a clean dedicated reference appliance are separate profiles. Modern iOS first; proposed minimum iOS 18 subject to toolchain and owner review. Android later using the same published protocol. macOS is a development adapter only.

| ID | Priority | Requirement / acceptance |
|---|---|---|
| F-BLE-01 | P0 | Native iOS central discovers Pi BLE peripheral by service UUID; no IP discovery or LAN permissions for control. |
| F-BLE-02 | P0 | On-TV QR starts bounded, expiring, one-time application enrollment; visible device confirmation; verifies Pi identity and authenticates client; no reusable secret in advertisements/logs. |
| F-BLE-03 | P0 | Remember device in Keychain and Pi trust store; reconnect securely, revoke, reset, reject revoked and unknown peers. No OS pairing assumptions; test actual behavior. |
| F-BLE-04 | P0 | D-pad, OK/back/home, touchpad, bounded text/scroll, volume and capability-based playback controls; command result/state sync; disconnect never stops current playback. |
| F-BLE-05 | P0 | Explicit connecting, permission denied, radio off, busy, unsupported, out-of-range and recovering states; keyboard/physical recovery path. |
| F-APP-01 | P0 | Strict versioned local manifest for web apps; one active foreground application, no provider branching in core, no arbitrary executable manifests. |
| F-APP-02 | P0 | Validate YouTube, Netflix, Spotify and Jellyfin on real hardware with legal accounts/content. Proposed release minimum: two distinct working providers, including video; owner explicitly approves unsupported services. Netflix not guaranteed. |
| F-TV-01 | P0 | Ten-foot launcher with spatial focus, app catalog, pairing and settings; no pointer dependency for own UI. Third-party pages may require touchpad. |
| F-OPS-01 | P0 | Non-root, systemd supervised, dedicated cgroup boundary, safe recovery; shared-host profile never shuts down host or modifies other services. |
| F-OPS-02 | P0 | Installable native Debian package, clean install/upgrade/remove/reinstall/rollback; signed APT distribution after validation. OS image later. |
| F-SEC-01 | P0 | No LAN control listener by default, no unauthenticated BLE commands, no shell/JS injection, no sandbox or DRM bypass. Local UI IPC not exposed to third-party pages; least privilege. |
| F-DES-01 | P0 | Central semantic tokens, component/state catalog, focus and accessibility contracts; TV and iOS cohesive but native conventions respected. |
| F-LIC-01 | P0 | GPLv3 code, separate trademark policy; corresponding source and notices, dependency and App Store license review. |
| F-FUT-01 | P2 | Android, native MPV, HDMI-CEC, optional IP remote, third-party catalogs, additional boards; separate ADR and no resource regressions. |

## Non-goals
No video casting over BLE, unofficial DRM/identity spoofing, LAN fallback enabled by default, full desktop, container runtime on Pi, cloud backend, custom browser/compositor/crypto, arbitrary third-party executable marketplace. Browser remote via Web Bluetooth is not assumed supported on iOS. No production Linux support claim beyond verified matrix.

## Candidate NFRs (validate before ratification)
Core idle PSS <=20 MiB and <=1% one logical core; system MemAvailable >=100 MiB on >=95% playback samples, no OOM or sustained swapping, no thermal throttling under declared cooling. 720p30 stable minimum / 1080p30 target for a validated video provider; <1% dropped frames if observable. BLE discrete command P95 <=100 ms from phone send to accepted/applied event (define both), pointer motion P95 <=150 ms; no loss of discrete commands after acknowledged acceptance except explicitly reported failure; reconnect P95 <=5 s foreground under repeatable in-range conditions. Candidate launcher JS <=200 KiB compressed, report uncompressed and parse/runtime cost; boot to launcher <=45 s. 24h soak and 72h release reliability gate; measure on Pi, not Mac. Define failure and abort thresholds and representative workloads first. Do not turn arbitrary budget numbers into guarantees.

## Decisions that need evidence
Browser/DRM, Cage vs labwc, BLE security handshake/library on Rust and Swift, single-browser lifecycle, exact iOS deployment target, actual shared-host safe limits, package/OS support and app-store license compatibility. Maintain compatibility matrix with date, versions, hardware, network, radio, codec, login, DRM, playback, input, latency, failures and evidence path.
