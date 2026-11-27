# Engineering policy

This policy describes proposed controls; it does not assert that CI or release tooling exists. Production implementation requires explicit owner approval.

## Dependencies and quality

Prefer existing facilities and minimal dependencies. Before admission, document purpose and alternatives, maintenance and security history, license compatibility and provenance, ARM64 support, transitive and native dependencies, footprint, update and removal path. Review toolchain pins and commit applicable lockfiles. Review security updates promptly according to severity and exposure; document assessment, mitigation and verification when an immediate update is impractical. Preserve third-party licenses and notices. Prepare an SBOM and corresponding notices for releases after provenance review.

Keep changes small and reviewable. Enforce module boundaries and typed errors; never hide failures, secrets or untrusted input. Review design tokens and component states against the design quality gates. Do not import historical prototypes into production.

## Verification and exceptions

Proposed future CI checks include formatting, lint, tests, dependency and license checks, boundary checks, reproducible generated assets, accessibility/design checks and secret scanning. No pipeline is implemented by this policy. Test unit and integration behavior, authorization and failure paths as applicable; record actual commands and outcomes. Hardware acceptance requires separate authorization and physical evidence.

The PRD proposes idle core PSS at most 20 MiB, initial launcher JavaScript at most 200 KiB compressed, and a 10% regression review threshold against a comparable validated baseline. These are not measured guarantees or ratified limits. Measure Pi memory, CPU, thermal behavior, latency and playback under representative workloads using [benchmarks](../architecture/BENCHMARKS.md); preserve existing workloads.

Document exceptions with rationale, scope, risk, owner approval, expiry or review date, and verification. Do not silently waive security, licensing or release requirements. Release signing and corresponding-source procedures remain pending Session 1C.4B.
