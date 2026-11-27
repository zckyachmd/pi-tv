# Requirement traceability and supersession

Proposed, 2026-11-27. Prior PRD is preserved at [v0.1](../archive/PRD-v0.1.md); old Phase 0 reports record what was tested, not current requirements. IDs in [current PRD](../../PRD.md) are authoritative for this proposal. Test gates below are not results.

| New IDs | Supersedes v0.1 | Design / acceptance evidence required |
|---|---|---|
| R-01, R-08 | F-01, F-09 | [System](SYSTEM_DESIGN.md): actual display, crash and recovery tests. |
| R-02–R-04 | F-02, F-07, F-08 and LAN/WSS security sections | [BLE](BLE_PROTOCOL.md), [threats](THREAT_MODEL.md): QR, identity, revoke, no-IP physical tests. Bonjour, WSS, LAN permission and manual IP fallback are no longer MVP requirements. |
| R-05 | F-03, F-06 | Protocol command fixtures, capability and real input tests. |
| R-06, R-13 | F-04–F-06, F-11 | [Boundaries](MODULE_BOUNDARIES.md), provider/manifest and hardware evidence. |
| R-07 | F-08, network exposure and security sections | Threat negative tests, local IPC isolation and independent security review. |
| R-09 | F-10, F-14 | Package lifecycle and recovery on actual target. |
| R-10, R-12 | shared-host and performance sections | [System](SYSTEM_DESIGN.md), existing [benchmark proposal](../../PHASE0C_BENCHMARK_PROTOCOL.md); thresholds reviewed before tests. |
| R-11 | compatibility and provider matrix | Actual versions and playback results; unknown remains untested. |
| R-14 | licensing and distribution sections | Provenance, license and platform distribution review. |

Old F-12 custom apps, F-13 browser remote and F-16 Android/other platforms are deferred. Old F-15 App Store delivery is conditional on distribution review, not an unconditional MVP requirement. The old numerical budgets and transport architecture are historical proposals; none are measured or silently ratified. Earlier Bonjour/WSS prototype findings remain valid only for the tested prototype.

## Requirement-level disposition of v0.1

The earlier summary table is supplemented by this explicit crosswalk. “Retained” means a proposal requiring validation, not a passed test. All links point to active specifications; archive and raw evidence remain historical.

| v0.1 source | Disposition | Active authority / outstanding evidence |
|---|---|---|
| F-01 | Retained: launcher, keyboard-free normal use and local recovery | [R-01, R-20](../../PRD.md); [recovery](RECOVERY.md) |
| F-02 | Superseded: Bonjour, manual IP and shared LAN replaced by BLE QR enrollment | [R-02, R-03](../../PRD.md); [protocol](BLE_PROTOCOL.md) |
| F-03 | Retained: remote inputs and visible state | [R-05](../../PRD.md); [protocol](BLE_PROTOCOL.md) |
| F-04 | Retained: catalog, lifecycle and generic manifests | [R-06, R-13](../../PRD.md) |
| F-05 | Retained: single foreground app and provider profile persistence | [R-06, R-08](../../PRD.md); [system](SYSTEM_DESIGN.md) |
| F-06 | Retained: capability-dependent controls and honest state | [R-05](../../PRD.md); [protocol](BLE_PROTOCOL.md) |
| F-07 | Retained: playback survives disconnect and state resynchronizes | [R-04](../../PRD.md); [protocol](BLE_PROTOCOL.md) |
| F-08 | Retained: least privilege, secrets, revocation and deliberate identity reset | [R-07, R-23](../../PRD.md); [recovery](RECOVERY.md) |
| F-09 | Retained: browser, service, network and HDMI recovery | [R-08, R-20](../../PRD.md) |
| F-10 | Retained: package lifecycle, state preservation and separate purge | [R-09, R-21](../../PRD.md) |
| F-11 | Retained: four reference providers, no unsupported claims | [R-11, R-15](../../PRD.md) |
| F-12 | Deferred: custom HTTPS apps and safe icon handling | [scope](../../PRD.md); future separate review |
| F-13 | Deferred: browser remote with secure onboarding | [scope](../../PRD.md) |
| F-14 | Signed APT and rollback retained for public distribution; image and recovery tooling deferred | [R-21](../../PRD.md); [deployment ADR](adr/005-deployment.md) |
| F-15 | Multi-device, accessibility and localization retained; store distribution conditional | [R-14, R-19, R-23](../../PRD.md); [license ADR](adr/006-license.md) |
| F-16 | Deferred: Android, native media, CEC, background audio and other hardware | [scope](../../PRD.md) |
| §§1–4 hardware, compatibility, isolation, lifecycle | Retained as target and evidence gates; reference OS and dependency choices unresolved | [R-01, R-06, R-10, R-11](../../PRD.md); [system](SYSTEM_DESIGN.md); [ADR index](adr/README.md) |
| §§5–6 LAN protocol and security | WSS, IP discovery and LAN-specific onboarding superseded; identity, least privilege, sandbox and secret protections retained | [R-07](../../PRD.md); [protocol](BLE_PROTOCOL.md); [threats](THREAT_MODEL.md) |
| §7 performance | Retained as proposals except LAN latency replaced by BLE measurements | [R-12, R-16–R-18](../../PRD.md); [benchmarks](BENCHMARKS.md) |
| §8 packaging and operations | Retained package state safety, signing and rollback; image deferred | [R-09, R-21](../../PRD.md) |
| §9 engineering governance | Retained dependency and test governance; detailed CI policy deferred | [R-22](../../PRD.md); [boundaries](MODULE_BOUNDARIES.md) |
| §§10–13 phases and evidence | Historical sequence superseded by current owner gates; observations preserved, no prototype implies target validation | [R-11–R-14](../../PRD.md); [risk register](RISK_REGISTER.md) |

The handoff BLE, application, operations, security and licensing proposals map to R-01–R-23. Handoff design-system detail is deferred to Session 1C.2; its accessibility and localization outcomes remain R-19. Hardware and physical-phone gates in the handoff roadmap remain unexecuted.
