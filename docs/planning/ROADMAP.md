# Pi TV — active roadmap proposal

Prepared against `6f95b24533afa21e51fcd1e65b9cba750efb2f90`. This supersedes the historical handoff phase numbering for future work, not the observations. All GO decisions require owner authorization; planning completion is not permission to run tests. See [backlog](IMPLEMENTATION_BACKLOG.md), [Session 2 runbook](SESSION_2_RUNBOOK.md), [benchmarks](../architecture/BENCHMARKS.md), [release gates](../engineering/RELEASE_GATES.md).

| Gate | Work | Exit / next decision |
|---|---|---|
| 1D | Consolidate 1C.5 and 1D; integrate documents and resolve active-spec conflicts | Review actual diff, check links/coverage, carry open blockers; request only 2A authorization |
| 2A | F-20–F-22: isolated Mac/iPhone BLE transport | Physical iPhone radio evidence, bounded framing, reconnect, no shared IP; no real authority granted; review before 2B |
| 2B | F-23: compare secure-channel candidates | Reviewed interoperability and negative tests; library admission; selected candidate remains unratified until 4 |
| 2C | F-24: enrollment, owner authority, recovery experiments | Independent security review, crash/race/role/credential tests; if no sound ceremony, no production |
| 3A | F-30–F-33: real Pi inventory, BlueZ, HDMI, runtime, no-HID acceptance | Actual device results; target work separately authorized; F-33 depends on 2C |
| 3B | F-34–F-35: lawful provider playback, resource and deployment feasibility | Actual 1 GB baseline, provider matrix, measured budgets, shared-host safety, deployment limitations |
| 4 | F-40: architecture ratification | Explicit owner decision on validated stack, numerical targets and supported scope; security gates cannot be waived by a documentation pass |
| 5 | P-01–P-03 foundation, P-04–P-08 vertical slice, P-09–P-11 MVP, P-12 hardening, P-13 release | Review each dependency group; separate release GO per artifact/channel |

## Parallelism and failure policy

F-20 host inspection and F-30 target read-only inventory can proceed independently with separate authorization. F-32 runtime/HDMI and F-34 media trials need no completed secure BLE implementation for isolated non-control experiments, but never count as remote acceptance. F-31 actual BlueZ may test inert fixtures after host transport validation; integrated authenticated acceptance needs F-23/F-24. F-35 network setup tests require an approved authorization design. Shared Host trials are not an alternative to an isolated baseline. Mac/simulator/container results cannot establish target or real-TV support. Hardware availability, legal test rights, security and explicit mutation consent are independent gates. Failed candidates are evidence: document failure, consider alternatives or reduce supported scope with owner approval; do not weaken security or fabricate PASS.

## Historical crosswalk

Phase 0/0B reports are historical host/build feasibility evidence. Original Phase 0C benchmark proposal is superseded by the active benchmark specification. Handoff 0C planning corresponds to 1A–1D; 0D BLE corresponds to 2A–2C; 0E physical target corresponds to 3A–3B; 0F ratification corresponds to 4. Handoff production phases 1–5 are grouped under gate 5 above. No historical incomplete result is promoted by renumbering.
