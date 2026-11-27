# Session 1C.1 — architecture and requirements checkpoint

2026-11-27. Baseline `dcf47308e50977dfc0e9709a48b2f9b2e8c936af`; planning changes only. Status: owner review required; no implementation or hardware results implied. The requirement crosswalk covers all sixteen archived F IDs and groups the remaining archived sections by topic; independent line-by-line completeness review remains outstanding.

| Finding | Disposition and evidence | Outstanding validation |
|---|---|---|
| F-01 | Specification substantially corrected: [PRD](../../PRD.md), [traceability](../architecture/TRACEABILITY.md) preserve named requirements and dispositions. | Independent line-by-line archive/handoff coverage review; owner ratification and actual acceptance tests. |
| F-02 | Specification clarified: [BLE protocol](../architecture/BLE_PROTOCOL.md), [system](../architecture/SYSTEM_DESIGN.md) separate four layers and candidate security channels. | Secure-channel design, interoperability, independent security review and physical testing. |
| F-03 | Specification proposed: [recovery](../architecture/RECOVERY.md) compares local mechanisms and specifies enrollment, revocation and reset paths. | Choose and approve trusted local mechanism; security, accessibility and crash testing. |
| F-04 | Specification coverage expanded: [ADR index](../architecture/adr/README.md) records candidates, tradeoffs and gates without duplicate ADRs. | Owner decisions and evidence; none newly validated or ratified. |
| F-05 | Specification expanded: [module boundaries](../architecture/MODULE_BOUNDARIES.md), [system](../architecture/SYSTEM_DESIGN.md) assign ownership, dependency direction and test boundaries. | Enforce when production structure exists; isolation and contract tests. |
| F-06 | Decision tracked: [ADR 006](../architecture/adr/006-license.md), [risk register](../architecture/RISK_REGISTER.md). | Confirm SPDX scope; provenance, third-party rights, trademark and iOS distribution review in Session 1C.4. |
| F-07 | Active proposed [benchmark specification](../architecture/BENCHMARKS.md) supersedes conflicting historical assumptions without editing evidence. | Threshold approval, instrumentation, physical device and workload testing. |

## Validation performed

- Python standard-library scan of local Markdown links in the active PRD and architecture/ADR documents: PASS at time of scan. This does not validate external URLs or anchors.
- Python scan of table-defined active requirement IDs: 23 unique, R-01 through R-23 present. Historical F-01 through F-16 all mentioned in traceability; this checks identifiers, not semantic completeness.
- ADR index scan: 001–006 referenced; local file link scan passed. Status semantics reviewed manually, not automatically proven.
- `git diff --name-only -- docs/archive evidence PHASE0C_BENCHMARK_PROTOCOL.md`: no tracked historical paths changed. New untracked files are inspected separately in working-tree review.
- `git diff --check`: passed after drafting this report (untracked files are not covered by this command).
- Supersession reviewed against the changed active documents: LAN discovery/WSS are described as historical or superseded. A full repository-wide semantic conflict audit remains outstanding.
- Hardware, interoperability, security, playback and soak tests: NOT RUN; not authorized in this session.

## Decisions and blockers for owner review

Select a secure-channel candidate only after interoperability and independent security evidence; approve a trusted provisioning and all-revoked recovery ceremony; decide schema and versioning, IPC isolation, persistence and identity migration, reference OS/dependencies, resource thresholds, packaging rollback, and supported provider scope. Confirm GPL identifier and scope after provenance and distribution review. Physical Pi and iPhone evidence remains mandatory before feasibility or release claims. Design system work, visual artifacts, root governance and provenance audit remain outside this session. No continuation into Session 1C.2 is authorized by this checkpoint.
