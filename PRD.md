# Pi TV product requirements — Session 1B proposal

Date: 2026-11-27. Status: owner direction incorporated; detailed acceptance, implementation and release criteria proposed, not ratified. [Earlier PRD](docs/archive/PRD-v0.1.md) and Phase 0 evidence remain historical. [Traceability and supersession](docs/architecture/TRACEABILITY.md) resolves conflicts. Pi TV is a working name, not a rights clearance.

## Product and decisions

A local-first HDMI entertainment appliance runs media on a Raspberry Pi; an iPhone is a remote, not a video relay. Owner-directed: Pi 4 Model B **1 GB physical RAM**, BLE remote with QR-assisted secure application enrollment, no shared Wi-Fi/LAN requirement, modern iOS first, Rust core, host-first macOS development, preservation of existing Pi workloads, provider/runtime/client independence. The Pi may independently use Ethernet or Wi-Fi for streaming. GPL-3.0-only is proposed for first-party code with a separate trademark policy; scope and distribution remain to be reviewed. SwiftUI/CoreBluetooth, BlueZ/BlueR and React/TypeScript/Vite are preferred candidates, not validated production decisions.

## Requirements and acceptance

P0 is MVP scope; each criterion requires recorded test conditions and results before a release claim.

| ID | Requirement and acceptance |
|---|---|
| R-01 | On a real Pi 4B 1 GB, boot to recoverable HDMI launcher, navigate by remote, and return home after browser failure; record board, OS, display and recovery path. |
| R-02 | Pair a physical iPhone by scanning a bounded, expiring one-use on-TV QR; authenticate device and phone, visibly confirm enrollment; reject wrong identity, expired and reused QR. No shared IP path is used. |
| R-03 | With phone Wi-Fi and cellular disabled, discover, authenticate, connect, send commands and reconnect over BLE; test Pi with network disconnected for local functions. Streaming independently needs provider connectivity. |
| R-04 | Paired-device list, revoke and reset work from trusted local UI; revoked/unknown devices cannot command; losing connection does not stop playback; reconnect obtains authoritative state without replay. |
| R-05 | Provide directional navigation, select, back, home, pointer, click, scroll, bounded text and volume; capability-dependent media commands return explicit unsupported or result status. Disconnect releases held keys. |
| R-06 | One foreground app; validated versioned non-executable manifests; add a vetted provider without provider-specific core/client changes. Do not claim a provider supported without recorded login, playback and input results on target. |
| R-07 | No unauthenticated command, remote shell, arbitrary JS, raw CDP, default LAN control or sandbox bypass; session, replay, downgrade, malformed input and hostile-page tests pass. |
| R-08 | Recover from daemon/browser/radio failures with bounded retries and explicit error states; preserve trusted state and provider profiles; no stale input after reconnect. |
| R-09 | Build and test a versioned ARM64 Debian package; install, upgrade, remove and reinstall preserve state unless explicitly purged; verify recovery on supported target before distribution. |
| R-10 | Dedicated Appliance and Shared Host profiles have documented resource accounting and abort thresholds; Shared Host cannot shut down host or disrupt unrelated services. Validate actual workload on 1 GB Pi before support claim. |
| R-11 | Document supported device/OS, display, iOS, BlueZ, browser, codec, DRM, provider and accessibility results with versions and dates; mark unknown as untested. |
| R-12 | Measure command accepted and applied latency, memory, swap, CPU, thermal and playback under representative workloads; report distributions, sample size and failures. Numeric targets are proposals, not guarantees. |
| R-13 | Rust core depends on domain ports, not provider, browser, BLE or UI implementations; conformance tests exercise mock transport and at least two independent provider manifests. |
| R-14 | Review first-party license scope, third-party notices, trademark rights, source distribution and iOS distribution terms before release; no App Store compatibility claim without review. |

## Scope and compatibility

MVP is foreground iOS BLE control and one foreground app. A browser-based mobile remote and Wi-Fi remote are outside MVP; Android, HDMI-CEC, other boards, native media runtimes and appliance images are deferred. No casting, cloud account, arbitrary executable marketplace, unsupported DRM bypass, or universal provider guarantee. Bluetooth radio denial, out-of-range, pairing failure and local recovery must be understandable. No background iOS operation is promised. Internet loss must not prevent local launcher and pairing when their dependencies remain available.

The exact iOS minimum, OS image, browser/compositor, crypto suite, handshake, GATT UUIDs, queue sizes and numerical performance budgets require feasibility and owner review. Existing LAN, Bonjour and WSS prototype behavior is historical; it is not the MVP transport. See [system design](docs/architecture/SYSTEM_DESIGN.md), [protocol](docs/architecture/BLE_PROTOCOL.md), [threat model](docs/architecture/THREAT_MODEL.md), [ADRs](docs/architecture/adr/README.md), and [risks](docs/architecture/RISK_REGISTER.md).
