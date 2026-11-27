# Phase 0C benchmark protocol — proposal for owner approval

No playback test has been run. This protocol is prepared for review and must not be executed against the shared Pi until package installation and test-window authorization are explicit. It preserves the 1 GB Pi 4 requirement and existing services.

## Measurement setup

- Record a sanitized run manifest: UTC timestamp, Pi model/OS/kernel, storage class, power supply, cooling, ambient temperature, display mode, network class, browser/compositor versions, content/provider, duration, command, and limitations. Never record hostname, IP, account, credential, pairing material, cookies, or typed provider content.
- Verify all existing workloads are healthy before each run. Abort before starting if Vaultwarden, Telegram Media Downloader, Cloudflare Tunnel, Docker/containerd, or a required host service is degraded.
- Keep the same Pi image, power, cooling, display, network, and content across comparisons. Do not change swap, kernel, firewall, system services, cgroup settings, or security controls during a run.
- Sample at 5-second intervals using `scripts/phase0b/sample-resources.py`; record a 10-minute idle baseline before platform tests. Capture service-health snapshots before and after each case with `pi-readonly-diagnostics.py`.
- Evaluate sampler overhead by comparing a 5-minute no-sampler interval with a 5-minute sampler interval under otherwise idle, equivalent conditions. Record sampler read time and CPU delta. If sampler overhead exceeds 1% of one logical core on average or changes `MemAvailable` by more than 5 MiB, increase the interval or remove PSS sampling before playback.
- Capture PSS from readable Chromium/compositor `smaps_rollup` entries, cgroup `memory.current`/`memory.peak`/events for the actual service slice, `MemAvailable`, PSI where present, swap-in/out deltas, whole-device I/O deltas, CPU, temperature, and throttling status. Missing signals are marked unavailable; do not substitute RSS sums for PSS.

## Test sequence

1. **Baseline idle:** 10 minutes with existing services in their normal state and no candidate browser running.
2. **Compositor and launcher idle:** 15 minutes after a non-root graphical session starts. Record cold startup time and steady-state metrics.
3. **Browser startup / idle:** three cold starts, then 10 minutes idle per run. Record launch-to-visible time, process count, total readable PSS, cgroup memory and audio-device readiness.
4. **Playback:** use owner-authorized, licensed reference content. Run 720p30 for 10 minutes after a 5-minute warm-up, repeated three times. Attempt 1080p30 only if all 720p30 runs meet abort criteria. Do not automate provider login or collect credentials.
5. **Lifecycle / recovery:** 30 app open/close cycles; after each close, capture memory; after the final close, observe recovery for 5 minutes. Record Chromium process/renderer count, launcher return time, PSS and cgroup memory. Do not clear browser profiles or cookies.
6. **Concurrent workload:** repeat one passing 720p30 case while representative, owner-approved existing service workloads run. Record workload commands and outputs in sanitized evidence; abort if service health changes.
7. **Soak:** only after short runs pass, owner approval, and package/DRM readiness; do a 2-hour per candidate provider run. Longer reliability runs belong to later release gates.

## Decode and frame evidence

Use local browser diagnostics only, with no remote-debugging listener. Capture the browser's GPU/codec status and media diagnostics through its local UI, plus observable decoder/video interfaces. Record content codec, resolution, frame counters, drops, warm-up exclusion and sample count. A codec listed as supported, V3D/HEVC driver presence, or `chrome://gpu` alone does not prove frames were hardware-decoded. If decode path or dropped-frame counter cannot be observed, mark it unavailable and do not claim a pass.

## Abort thresholds for owner review

These are proposed conservative stop conditions, not ratified product SLOs. Stop playback, return to the local launcher if safe, preserve services, and capture a read-only snapshot if any condition occurs:

- Any existing named service becomes unhealthy, stops, restarts unexpectedly, or reports an error attributable to the test.
- Any host or cgroup OOM-kill counter increases; any cgroup `oom`/`oom_kill` event increases.
- `MemAvailable` falls below 64 MiB at any sample, or below 100 MiB for two consecutive 5-second samples. The 100 MiB value matches the PRD's proposed headroom gate; these abort rules are deliberately earlier than a formal performance conclusion.
- Swap-in/out increases in two consecutive intervals after warm-up, or memory PSI reports sustained pressure. When PSI is unavailable, use `MemAvailable`, major-fault/swap deltas, cgroup events, service health, and responsiveness as fallback indicators.
- `vcgencmd get_throttled` reports a current undervoltage/throttle bit, or the measured core temperature reaches 75°C. Raspberry Pi documentation says Arm throttling begins in the 80–85°C range; 75°C is an early-stop margin for this shared-host test. [Raspberry Pi thermal management](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- Repeated visible stutter, audio underrun, loss of HDMI signal, unrecoverable compositor/browser crash, or loss of control-channel availability.
- Disk free space falls by more than 5% from the run start or I/O wait exceeds 20% for three consecutive samples. This is a protective proposed guard, not a product target.

Record every abort as a result, not a failed test to be rerun without diagnosis. Do not reboot the Pi or change system configuration to clear an abort condition.
