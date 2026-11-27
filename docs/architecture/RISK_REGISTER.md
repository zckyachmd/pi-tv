# Architecture and security risk register

Proposed 2026-11-27. Historical [Phase 0B risks](../archive/phase0/PHASE0B_RISK_REGISTER.md) are unchanged. Severity is a planning judgment, not a measurement.

| ID | Severity | Risk / current evidence | Gate / owner |
|---|---|---|---|
| S1 | Critical | No validated mutually authenticated Rust/Swift secure channel over GATT. | Security architect: independent review and interop test before production pairing. |
| S2 | High | BlueZ/BlueR advertising, GATT, permissions and 2.4 GHz coexistence unverified on target. | Platform engineer: authorized target capability and coexistence tests. |
| S3 | High | Browser/DRM/provider behavior and 1 GB workload not demonstrated. | Product owner: target matrix and release scope after benchmarks. |
| S4 | High | Hostile page or local process could reach privileged launcher/CDP interfaces. | Security architect: prove isolation and negative tests before integration. |
| S5 | High | Shared host could lose availability through memory, GPU, I/O or radio contention. | Owner: independent recovery, baseline, limits and abort criteria before authorized tests. |
| S6 | High | GPL-only scope, dependency compatibility, iOS distribution terms and trademark rights unresolved. | Owner/legal review before licensing or distribution. |
| S7 | Medium | Simulator install previously blocked; physical iOS permission and background behavior unknown. | Mobile engineer: repair simulator separately and test physical foreground flow. |
| S8 | Medium | QR disclosure or stolen unlocked phone can authorize an attacker. | Security review: reviewed phone confirmation, QR observation/race risks, expiry, revocation and recovery; communicate residual risk. |
| S9 | Medium | Version/fragment limits, command timing and memory ceilings are unmeasured. | Protocol/platform engineers: conformance, fuzz and target measurements before ratification. |
| S10 | Medium | Credential and enrollment atomicity across power loss is unspecified at implementation level. | Storage/security review: crash injection and durable transaction design. |
| S11 | High | Keyboard-free initial enrollment and lost-controller recovery lack approved authorization and credential-recovery mechanisms; QR observation can enable an attacker race. | Owner and security review: [recovery](RECOVERY.md), independent security, recovery-proof, race and crash tests before implementation. |
| S12 | High | Proposed PSS, bundle, latency, playback, soak and regression limits have no target baseline. | Owner/platform: approve [benchmark](BENCHMARKS.md) and measure physical devices before claims. |
| S13 | High | Public distribution lacks confirmed first-party license scope and provenance, compatible dependencies, source-delivery process and iOS terms review; trademark rights are unverified. | Owner/legal: [ADR 006](adr/006-license.md), Session 1C.4 audit and release gate. |
