# Phase 0B target host capability matrix

**Overall: BLOCKED for live verification.** No configured SSH aliases matching `pi`, `pi-tv`, `raspberrypi`, `raspberry-pi`, or `pi4` were found in this session. No connection was attempted. This is not evidence that the target is offline or inaccessible through another approved route.

The safe inventory script is ready at `scripts/phase0b/pi-readonly-diagnostics.py`. It reads system state only, takes a six-sample, five-second memory/swap snapshot, masks listener addresses, omits hostnames/container names/process command lines, and does not install packages or query credentials. It has not been run on the Pi.

| Capability | Current result | Source / next evidence |
|---|---|---|
| cgroup v2 controllers and memory accounting | **BLOCKED** | Earlier owner-reported inventory said PSI unavailable, but did not report cgroup version/controllers. Run the read-only diagnostic. |
| systemd resource-control capabilities | **BLOCKED** | Target systemd version and slice accounting properties not measured. |
| PSI and fallback metrics | PSI unavailable is **OWNER_REPORTED**; current PSI and fallback sampling **BLOCKED** | Collect `/proc/pressure`, `MemAvailable`, vmstat deltas, cgroup memory events, and interval metadata. |
| Memory, CPU, swap, disk I/O | Prior idle baseline **OWNER_REPORTED**: 906 MiB reported physical, 662 MiB available, 108 MiB swap used, 97–99% CPU idle, no swap movement during a short sample. Interval and raw output absent. New five-second sample **BLOCKED**. | Do not treat the owner-reported idle snapshot as a workload benchmark. |
| Existing service health | **BLOCKED** | Prior report lists Vaultwarden healthy, Telegram Media Downloader and Cloudflare Tunnel active, plus Docker/containerd and standard services. Current unit/container health not checked. |
| Listening port conflicts | Port 8080 occupied by Vaultwarden is **OWNER_REPORTED**; current listeners **BLOCKED** | The script reports only bind scope and port, not addresses. |
| DRM/GPU/video interfaces | Driver presence (DRM, V3D, V4L2, HEVC) is **OWNER_REPORTED**. Current device nodes and decoder interfaces **BLOCKED**. | Interface presence does not verify browser hardware decode. |
| HDMI/display modes | Both connectors disconnected is **OWNER_REPORTED**. Current status and modes **BLOCKED**. | Read connector status and modes from `/sys/class/drm`. |

## Exact read-only command

Run from an authorized SSH session or local Pi console:

```sh
python3 pi-readonly-diagnostics.py
```

The script path can be copied to the target first; copying a script is not an installation. Save its JSON output only after reviewing it for sensitive data. It intentionally contains no IP address, host name, credential, or provider content. The script's reported duration includes its fixed five-second sample.

Until live output is available, all cgroup, systemd, current service health, current port ownership, DRM/video-node, and HDMI-mode claims remain **BLOCKED** rather than inferred from the prior summary.
