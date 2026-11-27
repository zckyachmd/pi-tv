# Session 1 review — work in progress

Status: **incomplete; not approved for implementation**. This note is a review aid, not a replacement for the PRD or a ratified architecture. The handoff is under `handoff/pitv-planning-handoff/`; retain historical Phase 0 reports unchanged.

Reviewed checkout: `e179df40ea53690d13dd9a4915f962a7eccd75c8` on `main`; the handoff was untracked at review time.

## Owner direction and conflicts

The owner selected BLE with QR-assisted secure application pairing, modern iOS first, Pi 4B with 1 GB RAM, and GPLv3 with a separate trademark policy. `HOST_PREREQUISITES.md` section 4 still requires a shared LAN, Bonjour and WSS; those are historical instructions and must not be used as the MVP remote acceptance criteria. The existing Swift prototype implements Bonjour/WSS, not the selected BLE transport. It cannot establish BLE feasibility or security.

The choice of GPL-3.0-only versus GPL-3.0-or-later and the scope of the license remain owner decisions. The handoff's SwiftUI, GATT layout, cryptographic handshake, numerical performance limits, runtime, and distribution choices are proposals, not approvals.

## Evidence boundaries

`PHASE0B_HOST_FIRST_REPORT.md` reports an iOS simulator build but a blocked install, and explicitly does not establish physical iPhone behavior. Host browser navigation to public provider pages does not establish login, DRM, playback, or Pi compatibility. `PHASE0B_TARGET_CAPABILITIES.md` records target verification as blocked; owner-reported idle figures are not workload benchmarks. ARM64 build and ELF inspection are not target execution. The existing Phase 0 records must remain intact.

## Blocking work before approval

- Complete the PRD and ADR crosswalk, including stale networking requirements and prerequisites, with a clear proposal/ratification boundary.
- Verify upstream BLE, Apple, BlueZ, crypto-library interoperability, licensing and distribution documentation; record dated citations and actual versions. No secure handshake or library has been validated here.
- Complete the threat model, protocol contracts, design artifacts, governance and provenance audit, testing and release strategy, and dependency-ordered backlog specified by `CODEX_PROMPT.md`.
- Validate BLE and QR pairing with a physical iPhone and appropriate authorized test rig; simulator and Mac results cannot prove Pi BlueZ behavior. Separately gate Pi, HDMI, provider playback, resource and shared-host tests.
- Resolve App Store/GPL distribution compatibility and trademark rights through appropriate review before distribution.

No production implementation, hardware access, package installation or security relaxation is authorized by this note. Session 2 and subsequent hardware work remain behind separate approval gates.
