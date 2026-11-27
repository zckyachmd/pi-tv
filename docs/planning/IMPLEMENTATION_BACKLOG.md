# Pi TV — implementation backlog

Status: planning proposal prepared against GitHub commit `6f95b24533afa21e51fcd1e65b9cba750efb2f90`, 2026-11-27. No experiment, production work, distribution or hardware access authorized. Read the [PRD](../../PRD.md), [boundaries](../architecture/MODULE_BOUNDARIES.md), [ADRs](../architecture/adr/README.md), [roadmap](ROADMAP.md), [test strategy](../engineering/TEST_STRATEGY.md) and [release gates](../engineering/RELEASE_GATES.md). R-numbers refer to the PRD. Task IDs remain stable; split further only if needed. All tasks start pending. Effort S/M/L/XL = roughly one, two-to-three, four-to-seven, or more than seven focused engineering days respectively, not commitments; learning, owner availability and provider failures may dominate. Uncertainty L/M/H describes evidence gaps, not priority. No automatic progression between gates.

## Feasibility (disposable prototypes only)

| ID | Objective / scope | Requirements | Dependencies | Expected artifact and exit evidence | Approval | Effort / uncertainty |
|---|---|---|---|---|---|---|
| F-20 | Inventory Mac, signing, physical iPhone, BLE permissions, tools; verify right to use code privately | R-03, R-11, R-14 | 1D review | Dated tool/device matrix, confirmed physical deployment path, consent; blocked items explicit | Owner authorizes host and personal test device | S/M |
| F-21 | Mac peripheral / iPhone central GATT experiment; isolated UUIDs and fake payloads | R-03, R-07, R-12 | F-20 | Experimental code and logs; actual advertising, discovery, subscribe/write, negotiated lengths, disconnect/reconnect; no Wi-Fi or cellular on phone | Host experiment only | M/H |
| F-22 | Bounded transport and cross-language fixtures; fragmentation, backpressure, error handling | R-05, R-07, R-12, R-13 | F-21 | Transport fixture corpus, loss/reorder/overflow/saturation and reconnect results; memory caps measured | Same host scope | M/H |
| F-23 | Compare TLS 1.3 stream and Noise candidates, library admission, identity and session design | R-02, R-07, R-14, R-23 | F-20; F-22 for radio interop | Candidate matrix, pinned dependency/licensing evidence, reviewed construction, Rust–Swift interop and negative tests; no production credentials | Separate security-review and experimental dependency approval | L/H |
| F-24 | Keyboard-free bootstrap and durable owner/recovery lifecycle | R-01, R-02, R-04, R-07, R-08, R-20, R-23 | F-23 | Reviewed state machine, role/lease matrix, fake-store crash fixtures, physical-phone experiment with synthetic secrets; race/replay/rotation/loss tests | Separate owner and security approval for experiment | L/H |
| F-30 | Actual Pi read-only inventory, safe maintenance/recovery, existing workload baseline | R-10, R-11, R-12 | 1D review | Current board/OS/radio/display/packages/resource inventory, approved limits and stop path | Separate target read-only authorization | S/H |
| F-31 | Target BlueZ peripheral, headless first where appropriate, isolated service and transport port | R-03, R-07, R-10, R-12 | F-30, F-22 | Target GATT, coexistence, resource and permission evidence with fake commands; then approved security candidate only after F-23/F-24 | Separate package/radio/service and test-window approval | L/H |
| F-32 | HDMI/compositor/browser lifecycle, input routing and isolated launcher IPC | R-01, R-05, R-06, R-07, R-08, R-20 | F-30 | Real-TV 720p/1080p, sandbox and hostile-page negatives, process cleanup, CDP isolation, input and HDMI recovery | Separate approved test window and target changes | L/H |
| F-33 | Actual Pi + TV + iPhone no-HID onboarding and recovery | R-01–R-05, R-07, R-08, R-20, R-23, R-24 | F-24, F-31, F-32 | Prepared media, physical end-to-end synthetic/local fixture, power-loss, reconnect and replacement recovery; no unauthenticated bypass | Security review and owner hardware authorization | L/H |
| F-34 | Provider media/DRM matrix and 1 GB resource feasibility | R-06, R-10–R-12, R-15–R-18 | F-30, F-32; F-31 for coexistence | Lawful playback tests, observed codec/resolution/drops, memory/CPU/thermal/swap and workload impact; limitations documented | Test accounts and workload scope approved | XL/H |
| F-35 | Dedicated and shared deployment/network/recovery feasibility | R-09, R-10, R-20, R-21, R-24, R-25 | F-30, F-31, F-32; F-24 for authenticated setup | Candidate package lifecycle, rollback and least-privilege network adapter; Ethernet fallback; no shared network mutations without approval | Explicit maintenance/mutation consent | L/H |
| F-40 | Architecture ratification | R-01–R-25 | Required F-20–F-24, F-30–F-35 evidence reviewed; owner dispositions for failed/optional items | ADRs updated with evidence and rejected options; support matrix, approved targets and security verdict; NO-GO if hard requirements fail | Explicit owner approval and independent security review | M/H |

## Production (locked until F-40)

| ID | Objective / scope | Requirements | Dependencies | Expected artifact and acceptance | Approval | Effort / uncertainty |
|---|---|---|---|---|---|---|
| P-01 | Minimal workspace, toolchains, boundaries, CI checks, dependency admission | R-13, R-17, R-22 | F-40 | Reproducible pinned builds, lint/tests/import checks, no empty speculative crates | Production GO | M/M |
| P-02 | Canonical protocol/schema and fixtures; typed errors and bounded domain types | R-05, R-07, R-12, R-13 | P-01 | Cross-language positive/negative compatibility fixtures, fuzz limits and version policy | Reviewed protocol decision | M/M |
| P-03 | Core lifecycle, authoritative state, actor/ports, command admission and capabilities | R-01, R-05, R-06, R-08, R-13 | P-02 | Fake adapter tests for timeouts, stale generations, bounded queues, cleanup and unknown outcomes | Production GO | L/M |
| P-04 | Trust persistence, enrolled identities, secure session and ownership/recovery | R-02, R-04, R-07, R-23 | P-02, F-23, F-24 | Reviewed implementation, cross-language auth, revocation, crash and recovery tests | Independent security review | XL/H |
| P-05 | BlueZ adapter and service composition | R-03, R-07, R-10, R-12 | P-03, P-04, F-31 | Real Pi integration, limits, shutdown, reconnect, permission tests | Target test consent | L/M |
| P-06 | Runtime adapter, isolated launcher IPC, catalog and input | R-01, R-05–R-08, R-13 | P-03, F-32 | Local sample runtime, provider-agnostic manifests, private IPC negatives, lifecycle tests | Security/platform review | L/H |
| P-07 | Token mapping/drift checks and TV launcher | R-01, R-06, R-17, R-19, R-20 | P-02, P-06 | Active v2 design mapped to actual focus graph, accessibility, 720p/1080p visual regression; bundle measured | Design review | L/M |
| P-08 | Native iOS remote with client session, pairing, D-pad, touchpad, keyboard, capabilities | R-02–R-05, R-07, R-19, R-23 | P-02, P-04, P-05 | Physical iPhone vertical slice and negative-path tests; no false Ready state | Internal test rights/signing; no distribution | XL/H |
| P-09 | Prepared-media onboarding, device management, secure recovery and network setup | R-01–R-04, R-08, R-20, R-23–R-25 | P-04–P-08, F-35 | Full keyboard-free flow, interrupted commits and reset, authenticated network rollback; no unowned fallback on corruption | Security and owner review | L/H |
| P-10 | Provider compatibility and lifecycle qualification | R-06, R-11, R-15, R-16 | P-06–P-09, F-34 | Per-provider verified/degraded/unsupported matrix; owner accepts scope, no DRM bypass | Authorized lawful accounts | L/H |
| P-11 | Native Debian package, service units, prepared media, upgrade/rollback | R-09, R-10, R-21, R-24 | P-05–P-09, F-35 | Clean/upgrade/interrupted install, remove vs purge, trust/profile preservation; distinct shared/dedicated policies | Target maintenance consent | L/H |
| P-12 | Hardening and reliability | R-07, R-08, R-10–R-12, R-16–R-19 | P-09–P-11 | Security and accessibility tests, 30 switches, 24h integrated soak, regression and real device evidence | Independent review and soak authorization | XL/H |
| P-13 | Distribution readiness | R-14, R-18, R-21, R-22, R-24 | P-11, P-12 | 72h release reliability, actual-build SBOM/notices, rights review, signed artifacts/source/rollback and release checklist | Explicit channel-specific release GO | L/H |

## Cross-cutting decisions

- INT-01 → F-24/P-04/P-09: durable owner commit before bootstrap closes; recovery setup remains pending if interrupted, never revert owned to unowned.
- INT-02 → F-23/F-24/P-04: management authorization distinct from control lease; test authorized owner access when ordinary controller is active; no unauthenticated preemption.
- INT-03 → documentation reconciliation now; F-24/F-33 validate no-HID owned recovery and reset transitions.
- INT-04 → F-35/P-09: Wi-Fi-only plug-and-play requires authenticated setup; Ethernet-only fallback explicitly disclosed. Shared Host mutation blocked by default.
- INT-05 → documentation reconciliation now; canonical tokens and active v2 artwork only, handoffs immutable.
- GOV-01–06 → [release gates](../engineering/RELEASE_GATES.md); unresolved rights affect actual material/use and recipients, not blanket authorization to test or publish.
