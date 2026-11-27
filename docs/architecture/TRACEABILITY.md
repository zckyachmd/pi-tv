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
