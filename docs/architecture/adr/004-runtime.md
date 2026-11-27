# ADR 004 — Foreground runtime and launcher

Status: proposed; authority: product owner after platform/security review.

**Context:** 1 GB hardware, untrusted providers and provider-independent behavior. **Alternatives:** one managed browser process tree, multiple foreground runtimes, or a native runtime. **Direction:** one foreground runtime behind a narrow port; React/TypeScript/Vite static launcher preferred; OS browser/compositor selected by evidence. **Rationale/tradeoff:** bounded lifecycle and generic integration; Chromium may still exceed budget and provider DRM may fail. **Evidence:** [Phase 0 host report](../../../PHASE0B_HOST_FIRST_REPORT.md) demonstrates host navigation only. **Consequences:** no provider-specific core, no disabled sandbox, private debugging boundary and no runtime Node requirement. **Validation:** target playback, login, process cleanup, sandbox/IPC negative tests, bundle and memory measurement.
