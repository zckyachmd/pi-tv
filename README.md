# Pi TV

**Status: planning complete in substance; Session 2A awaits owner authorization.** No production implementation or physical target certification.

Pi TV is a planned local-first HDMI entertainment appliance for Raspberry Pi 4 Model B with 1 GB RAM. An iPhone remote is intended to control it over BLE, with QR-assisted enrollment; the phone is not a video relay and shared Wi-Fi is not required. Streaming may require independent internet access.

The proposed architecture separates a Rust core and its ports from BLE, storage and browser adapters, a TV launcher, and an iOS remote. Customer operation is intended to be keyboard-free. First boot requires prepared media or a documented preparation process for an existing OS; no phone-based flashing is promised.

This repository contains planning, design and feasibility evidence, plus historical prototypes. Production software, security, provider compatibility and operation on the target hardware are not established. The BLE remote, playback and recovery are proposed and require physical and security validation. Historical LAN prototypes do not establish MVP support.

Start with the [PRD](PRD.md), [documentation index](docs/README.md), [module boundaries](docs/architecture/MODULE_BOUNDARIES.md), and [feasibility report](docs/archive/phase0/PHASE0_FEASIBILITY.md). Host-first development prerequisites are described in [host prerequisites](HOST_PREREQUISITES.md); production implementation requires owner approval. Contributions and security concerns follow [CONTRIBUTING](CONTRIBUTING.md) and [SECURITY](SECURITY.md).

The owner selected GPL-3.0-only for the first-party Rust core and TV launcher; other material has distinct or unresolved scope. See [LICENSING](LICENSING.md).

## Repository layout

| Path | Purpose |
|---|---|
| `PRD.md` | Current product requirements |
| `HOST_PREREQUISITES.md` | Development and test prerequisites |
| `docs/architecture/` | Specifications and ADRs |
| `docs/design/` | Canonical design tokens and active wireframes |
| `docs/engineering/` | Engineering policy, test strategy and release gates |
| `docs/planning/` | Roadmap, backlog, runbooks and checkpoints |
| `docs/archive/` | Historical reports and immutable archive index |
| `prototypes/`, `scripts/phase0b/`, `evidence/` | Historical experimental code, scripts and raw evidence; not production |

Next gate: [Session 2A runbook](docs/planning/SESSION_2_RUNBOOK.md). Historical handoffs and superseded wireframes are accessible through the [archive index](docs/archive/README.md), not active implementation inputs.
