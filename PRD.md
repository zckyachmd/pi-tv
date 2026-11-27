# Pi TV product requirements — Session 1B proposal

Date: 2026-11-27. Status: owner direction incorporated; detailed acceptance, implementation and release criteria proposed, not ratified. [Earlier PRD](docs/archive/PRD-v0.1.md) and Phase 0 evidence remain historical. [Traceability and supersession](docs/architecture/TRACEABILITY.md) resolves conflicts. Pi TV is a working name, not a rights clearance.

## Product and decisions

A local-first HDMI entertainment appliance runs media on a Raspberry Pi; an iPhone is a remote, not a video relay. Owner-directed: Pi 4 Model B **1 GB physical RAM**, BLE remote with QR-assisted secure application enrollment, no shared Wi-Fi/LAN requirement, modern iOS first, Rust core, host-first macOS development, preservation of existing Pi workloads, provider/runtime/client independence. The Pi may independently use Ethernet or Wi-Fi for streaming. GPL-3.0-only is proposed for first-party code with a separate trademark policy; scope and distribution remain to be reviewed. SwiftUI/CoreBluetooth, BlueZ/BlueR and React/TypeScript/Vite are preferred candidates, not validated production decisions.

## Requirements and acceptance

P0 is MVP scope; each criterion requires recorded test conditions and results before a release claim.

| ID | Requirement and acceptance |
|---|---|
| R-01 | On a real Pi 4B 1 GB, boot prepared media automatically to the HDMI launcher and enrollment; use only TV display and iPhone over BLE for first boot, operation and recoverable browser failure, without extra input peripherals or mandatory CEC; record board, OS, display and recovery path. |
| R-02 | Pair a physical iPhone by scanning a bounded, expiring one-use on-TV QR; authenticate device and phone, compare display and explicitly confirm on iPhone through a security-reviewed ceremony; reject wrong identity, expired and reused QR. No shared IP path is used. |
| R-03 | With phone Wi-Fi and cellular disabled, discover, authenticate, connect, send commands and reconnect over BLE; test Pi with network disconnected for local functions. Streaming independently needs provider connectivity. |
| R-04 | Authorized iPhone workflows support paired-device list, add, revoke, replacement and reset; revoked/unknown devices cannot command; losing connection does not stop playback; reconnect obtains authoritative state without replay. |
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

MVP is foreground iOS BLE control and one foreground app. A browser-based mobile remote and Wi-Fi remote are outside MVP; Android, HDMI-CEC, other boards, native media runtimes are deferred. No casting, cloud account, arbitrary executable marketplace, unsupported DRM bypass, or universal provider guarantee. Bluetooth radio denial, out-of-range, pairing failure and local recovery must be understandable. No background iOS operation is promised. Internet loss must not prevent local launcher and pairing when their dependencies remain available.

The exact iOS minimum, OS image, browser/compositor, crypto suite, handshake, GATT UUIDs, queue sizes and numerical performance budgets require feasibility and owner review. Existing LAN, Bonjour and WSS prototype behavior is historical; it is not the MVP transport. See [system design](docs/architecture/SYSTEM_DESIGN.md), [protocol](docs/architecture/BLE_PROTOCOL.md), [threat model](docs/architecture/THREAT_MODEL.md), [ADRs](docs/architecture/adr/README.md), and [risks](docs/architecture/RISK_REGISTER.md).

## Preserved requirements and pending acceptance decisions

The following are active proposals, not measurements or ratified limits. See [traceability](docs/architecture/TRACEABILITY.md) for individual historical dispositions and [benchmark specification](docs/architecture/BENCHMARKS.md) for measurement gates.

| ID | Requirement |
|---|---|
| R-15 | Evaluate YouTube, Netflix, Spotify and Jellyfin as reference applications with lawful accounts on target hardware. Publish each result and limitations; proposed release minimum is two distinct validated services including video, subject to owner approval if a reference service is unsupported. |
| R-16 | Propose stable 720p30 minimum and 1080p30 target on a validated video path; output resolution does not prove playback resolution. Report observability and dropped frames. |
| R-17 | Propose idle core PSS ≤20 MiB and initial launcher JavaScript ≤200 KiB compressed. Propose ≤10% regression in core memory, CPU and latency against a validated comparable baseline, or reviewed ADR and new baseline; hard gates still apply. |
| R-18 | Propose 2-hour provider trials, an integrated 24-hour soak including reconnect and switching, and a 72-hour release reliability run on the actual Pi. |
| R-19 | Design for accessibility and localization readiness, including screen-reader semantics, focus, contrast, reduced motion and externalizable text; define platform-specific acceptance before release. |
| R-20 | Recover HDMI disconnect/reconnect and display actionable local recovery. First boot, enrollment, normal operation, controller management and recoverable failures require no keyboard, mouse, extra controller, GPIO button, SSH or mandatory HDMI-CEC. Fatal hardware/OS failures or loss of all ownership proof require documented maintenance. |
| R-21 | Before public distribution, validate signed APT Release metadata with a scoped keyring and document rollback using a compatible prior package and configuration backup; test interrupted upgrades and restore. APT rollback is not automatic. |
| R-22 | Govern dependencies through reviewed admission, pinned toolchains and lockfiles, license and vulnerability review, maintained update paths and release notices/SBOM; exceptions require owner review. |
| R-24 | Provide pre-provisioned media or a documented installer/preparation for an existing OS; the Debian package remains the packaging source. Do not clone device keys or redistribute proprietary CDMs without permission. No claim that iPhone flashes media. |
| R-25 | Optionally configure Pi internet through an authenticated protected BLE session, least-privilege adapter, owner approval and rollback; Ethernet remains an alternative. Never log or leak credentials. Shared-host network changes are disabled unless separately authorized. Offline launcher and pairing must work without shared Wi-Fi. |
| R-23 | Support multiple saved trusted device identities, explicit device selection and revocation, credential storage and replacement/reset recovery. Identity rotation and migration require a reviewed design; no credential or profile deletion on ordinary upgrade. |

Custom user-supplied apps, browser remote, Android, additional boards, native media, background audio, mandatory HDMI-CEC is excluded. TestFlight/App Store distribution is conditional on licensing and platform review. Prepared media and first-boot security gates are specified in [recovery](docs/architecture/RECOVERY.md). Older LAN latency, Bonjour, WSS and shared-LAN requirements are superseded, not restored.
