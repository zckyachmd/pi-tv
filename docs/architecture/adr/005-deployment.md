# ADR 005 — Deployment profiles

Status: protecting existing workloads owner-directed; isolation mechanics proposed. Authority: owner after operations review.

**Context:** 1 GB Pi may already host important workloads. **Alternatives:** dedicated appliance, shared host, containers or a new supervisor. **Direction:** dedicated appliance reference and separately validated Shared Host using existing systemd and resource controls. **Rationale/tradeoff:** OS supervision avoids a new service; cgroups cannot prevent all contention. **Evidence:** [target capability report](../../../PHASE0B_TARGET_CAPABILITIES.md) is blocked for live verification. **Consequences:** no host shutdown or global service/radio changes by default; no shared-host support claim yet. **Validation:** approved baseline, abort thresholds, cgroup capabilities, representative workload and independent recovery on actual target.

Prepared media or a documented installer for an existing OS is required for appliance onboarding; the Debian package remains the source. No cloned device keys or unlicensed proprietary CDMs. Optional authenticated BLE network setup requires owner approval, rollback, and least privilege; shared-host network changes remain disabled unless separately authorized.
