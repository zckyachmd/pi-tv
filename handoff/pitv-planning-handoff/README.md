# Pi TV — pre-implementation handoff

Prepared 2026-11-27. Target repository: https://github.com/zckyachmd/pi-tv. Reviewed snapshot: `e179df40ea53690d13dd9a4915f962a7eccd75c8` (tree returned for main). This is a proposed planning bundle, not a replacement for the repository PRD or an assertion that hardware tests passed.

## Use
1. Extract into a temporary directory in the existing repository, e.g. `handoff/2026-11-27/`. Do not overwrite existing documents blindly.
2. Start Codex at the repository root. Give it `CODEX_PROMPT.md` as the instruction and ask it to read all files here and existing reports.
3. Codex reconciles the current checkout, preserves historical evidence and produces a reviewable planning PR/diff. Do not publish, deploy, install on the Pi or start production implementation without the appropriate owner approval.

## Bundle
- `PRD_CHANGESET.md`: proposed superseding requirements; Wi-Fi-independent BLE control.
- `ARCHITECTURE.md`: module boundaries, platform/transport interfaces, security and lifecycle.
- `BLE_SPEC.md`: candidate GATT/framing/pairing requirements, spike and failure cases.
- `DESIGN_SYSTEM.md`, `design-tokens.json`: shared visual language, accessible TV/iOS UX and candidate token seed.
- `ROADMAP_AND_GATES.md`: evidence review, work packages, prerequisite checks, phase and release gates.
- `LICENSE`: unmodified GNU GPL v3 text, candidate for repository root after provenance review.
- `TRADEMARK_POLICY.md`: proposed separate trademark policy, subject to rights/name review.
- `GOVERNANCE.md`: licensing scope, contribution, dependency, documentation and CI rules.
- `CODEX_PROMPT.md`: execution instructions.

Owner decisions: Pi 4B 1 GB; modern iOS first; platform-agnostic; lightweight and maintainable; host-first development; Bluetooth control and QR pairing; GPLv3 + trademark policy. Proposed defaults not explicitly selected: GPL-3.0-only rather than or-later, SwiftUI, BLE GATT specifics, visual tokens, detailed security protocol and numerical gates. Confirm before production. No direct Codex session or repository mutation is performed by this bundle.
