# Session 1B completion and owner review

2026-11-27. Planning artifacts are complete for review, not ratified or an authorization to implement. The checkout at start was `e179df40ea53690d13dd9a4915f962a7eccd75c8`; untracked handoff and earlier review were preserved. The earlier PRD and prerequisites were copied into `docs/archive/` before replacement. No physical device access, experiments, packages, radio changes, production code, push or merge were performed.

| Deliverable | Status and remaining validation |
|---|---|
| [PRD](../../PRD.md) | Reconciled proposal; owner review of acceptance and release scope, target tests required. |
| [Host prerequisites](../../HOST_PREREQUISITES.md) | Reconciled; actual host and target inventories, signing and physical iPhone remain to verify. |
| [System design](../architecture/SYSTEM_DESIGN.md) | Proposed boundaries, diagrams, lifecycle and profiles; IPC isolation, target resource controls and browser lifecycle require validation. |
| [Module boundaries](../architecture/MODULE_BOUNDARIES.md) | Proposed dependency rules; enforce when implementation is authorized. |
| [BLE protocol](../architecture/BLE_PROTOCOL.md) | Behavioral candidate; exact wire format, UUIDs, secure channel and bounds remain unselected/unvalidated. No production implementation until security gate. |
| [Threat model](../architecture/THREAT_MODEL.md) | Proposed threats, tests and residual risks; independent security review and physical tests required. |
| [ADR index and six decisions](../architecture/adr/README.md) | Owner direction distinguished from proposals; no ADR validated or ratified. |
| [Traceability](../architecture/TRACEABILITY.md) | Maps old requirements and explicit supersessions; future tests need evidence links. |
| [Risk register](../architecture/RISK_REGISTER.md) | Updated planning risks; old risk evidence unchanged. Severity and ownership to be confirmed. |

## Evidence and decisions

The historical [Phase 0 feasibility report](../archive/phase0/PHASE0_FEASIBILITY.md), [host-first report](../archive/phase0/PHASE0B_HOST_FIRST_REPORT.md), [build report](../archive/phase0/PHASE0B_BUILD_REPORT.md), [package report](../archive/phase0/PHASE0B_PACKAGE_REPORT.md), [target matrix](../archive/phase0/PHASE0B_TARGET_CAPABILITIES.md) and [evidence index](../../evidence/phase0b/README.md) distinguish host checks from target execution. Host browser tests load provider landing pages, not verified provider playback. The iOS app built for simulator but install timed out. ARM64 artifacts were built/inspected in a container, not run on Pi. Package plans are simulations and installed size is disk, not RAM. Owner-reported idle numbers are not workload measurements. No BLE secure channel, physical iPhone, BlueZ target, HDMI, DRM or shared-host playback result is established.

Owner direction is recorded in the PRD. Remaining decisions include exact iOS deployment floor, platform and runtime versions, provider release threshold, numerical performance limits, license scope and distribution route. The secure-channel decision must specify a maintained interoperable Rust/Swift solution, identities, transcript binding, rotation, secure storage and durable enrollment before production; neither TLS-over-GATT nor Noise is approved. BlueZ/BlueR capability and whether the local launcher and CDP can be isolated safely are open. GPL/App Store compatibility and trademark rights need appropriate review, not an assumption.

## Review and next gate

Review the PRD, ADRs, protocol and threat model together. Ask security and platform reviewers to assess the secure-channel options and IPC isolation; approve a separately scoped host-first BLE/QR spike only after deciding its test boundaries. Physical target access, deployment, system changes, and production implementation require separate authorization. The historical benchmark is still a proposal: replace or amend its LAN-era assumptions and obtain approved thresholds before using it.

Local verification: inspect with `git status --short`, `git diff -- PRD.md HOST_PREREQUISITES.md` and `git diff --no-index /dev/null docs/architecture` as applicable; untracked documents do not appear in ordinary `git diff`. No runtime tests were run for this documentation-only change. Source references are dated in the relevant documents; recheck library maintenance, versions, licenses and Apple requirements before selection or release.
