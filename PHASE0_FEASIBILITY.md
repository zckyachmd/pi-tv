# Phase 0 feasibility update

Updated 27 November 2026 from development-host checks, disposable prototypes, package simulations and the supplied Raspberry Pi inventory. This is an evidence update, not Phase 0 approval. A short Pi observation is not a playback benchmark, and no full product implementation is authorized before the owner approves the Phase 0 review gate.

**Current disposition:** Phase 0 remains in progress. The owner has authorized host-first macOS prototyping without Pi or HDMI dependency, while the Pi 4B with 1 GB physical RAM remains the required production target. The host-first prototype advances engineering evidence only; it does not prove Pi performance, video playback, hardware decoding, DRM, or Linux ABI compatibility. The candidate Shared Host baseline remains an investigation proposal. No candidate ADR is ratified and no production implementation is authorized before owner review.

Host-first build/browser/mobile evidence and reproducible commands: [`PHASE0B_HOST_FIRST_REPORT.md`](PHASE0B_HOST_FIRST_REPORT.md). Package simulation details: [`PHASE0B_PACKAGE_REPORT.md`](PHASE0B_PACKAGE_REPORT.md). Open risks: [`PHASE0B_RISK_REGISTER.md`](PHASE0B_RISK_REGISTER.md).

## Evidence labels

- **Verified here** — directly checked on the development host in this session.
- **Reported observation** — supplied from the actual Pi host; raw command output, exact sampling interval and test conditions were not attached.
- **Proposal** — an architecture candidate for review, not an approved decision.
- **Untested** — no evidence yet; do not infer success from inventory presence.
- **Blocked** — evidence requires unavailable target access, owner authorization or external hardware/account conditions.

## Development host

| Item | Status and evidence |
|---|---|
| Platform | **Verified here:** macOS ARM64 (`Darwin arm64`). |
| Rust resolution and pin | **Verified here:** login shell selects rustup Rust 1.100.0 from `rust-toolchain.toml`; components and `aarch64-unknown-linux-gnu` target are installed. Some non-login tool invocations resolve Homebrew first, so reproducible commands explicitly use `zsh -lc`. |
| ARM64 Linux build | **Verified for disposable smoke and daemon ELFs:** pinned Debian 12 ARM64 builder compiled the locked daemon; ELF inspection found AArch64 PIE and a highest required glibc symbol of 2.34. The std-only smoke binary also ran inside the ARM64 container. Neither binary was run on the actual Pi; target OS/runtime compatibility remains unverified. See `PHASE0B_BUILD_REPORT.md`. |
| Xcode, SDK and simulator | **Verified present:** Xcode 27.2, iPhoneOS SDK 27.2 and iOS 27.2 simulator runtime. Swift-native prototype simulator-SDK compilation result is recorded in `PHASE0B_HOST_FIRST_REPORT.md`; no signed app or device runtime test. |
| Node/pnpm/Chrome | **Verified present:** Node 26.13.1, npm 11.20.0, pnpm 12.21.0 and Google Chrome 158.0.8127.37. No separate Chromium app found. |
| Host-first browser behavior | **Verified with limits:** isolated Chrome startup/termination, loopback CDP, D-pad/text/pointer/scroll, fullscreen API, generic media play/pause, one-page lifecycle and temporary-profile recovery; provider landing pages only. Media-key mapping and seek remain unverified. |

The PATH adjustment affects new login shells. Existing shells need to source `~/.cargo/env` or restart. The toolchain pin records the compiler validated by version and component checks; it does not establish Linux binary compatibility.

## Raspberry Pi 4B, 1 GB

The following are **reported observations** from the actual target. The brief sampling interval has no exact duration or raw command output attached.

| Area | Reported observation | What it establishes |
|---|---|---|
| Memory | 906 MiB physical reported; 662 MiB available; approximately 244 MiB non-available baseline | A short idle baseline only; no playback headroom conclusion. |
| CPU and thermals | 97–99% idle in the short sample; 42.8°C; throttling `0x0` | Idle condition only; playback CPU and thermal behavior remain untested. |
| Swap | Two disk-backed swap files totaling 2 GiB; 108 MiB used; no swap-in/out observed during short sampling | Existing host configuration only; swap capacity is not physical memory and is not a playback result. |
| Pressure telemetry | PSI interfaces unavailable | Diagnostics must tolerate absent PSI and report the signal as unavailable. |
| Graphics/media devices | DRM, V3D, V4L2, HEVC, HDMI audio and CEC drivers present | Driver presence only; display, codec path and hardware-accelerated browser decoding remain unverified. |
| Display | Both HDMI connectors disconnected | HDMI detection and display-mode validation remain open. |

## Shared-host inventory and protection boundary

Reported existing workloads are a healthy Vaultwarden Docker container with a 96 MiB memory limit, Telegram Media Downloader, Cloudflare Tunnel, Docker/containerd, Avahi, NetworkManager and standard system services. Vaultwarden occupies host port 8080. The entertainment platform must preserve these workloads and use separate systemd units plus a dedicated resource-isolation boundary.

The host cgroup capabilities and suitable production limits have not been evaluated. No playback test has been run while existing services execute representative workloads. Do not change kernel configuration, swap configuration, system services or firewall settings without explicit owner approval.

## Candidate ADRs — proposals only

These candidates update the PRD architecture table. None is ratified by this report.

| Candidate | Proposal for owner review | Evidence or gate still needed |
|---|---|---|
| ADR-C01 — Shared Host isolation | Treat the Pi as a shared, security-sensitive host; separate systemd units and a dedicated resource-isolation boundary; preserve existing services and containers. | Inspect cgroup version/controllers and service interactions; test install, operation and recovery without disrupting workloads. |
| ADR-C02 — Resource controls and diagnostics | Evaluate cgroup accounting and controls before setting limits. Diagnostics discover capabilities and gracefully report unavailable metrics, including PSI. | Compare supported memory controls and instrumentation overhead on the actual OS. |
| ADR-C03 — Listener configuration | Make every listening port configurable and fail clearly on port conflicts. | Define bind-address defaults, required ports and safe recovery behavior; account for the existing port 8080 owner. |
| ADR-C04 — Browser/control exposure | Keep browser debugging private to the graphical session; never expose debugging or unauthenticated control endpoints to LAN or Cloudflare Tunnel. | Secure local networking and pairing spike, including bind behavior and tunnel reachability checks. |
| ADR-C05 — Shared Host privileges | Disable host shutdown capability by default in Shared Host mode. | Review any future privileged action separately and require a narrow authorization design before enabling it. |
| ADR-C06 — Swap and ZRAM | Do not use swap capacity as a substitute for RAM; evaluate ZRAM only in a controlled comparative benchmark. | Compare the current disk-backed swap setup and ZRAM under equivalent workloads; no swap setting changes without approval. |
| ADR-C07 — Concurrent playback gate | Measure playback while existing services execute representative workloads. | Define repeatable workload, content, duration, power/cooling and sampling protocol; record service health and resource data. |
| ADR-C08 — Host-first runtime adapters | Develop on macOS behind a runtime boundary while keeping Linux/Pi as the mandatory production target. | Host-only macOS adapter exists; Linux runtime and Pi execution remain untested. See `PHASE0B_HOST_FIRST_REPORT.md`. |
| ADR-C09 — Client-independent protocol | Keep local HTTP/JSON and WebSocket commands separate from runtime/provider details. | Mock WebSocket dispatch is testable; authenticated LAN transport, limits and real iOS interoperability remain open. |
| ADR-C10 — Native iOS vs React Native | Consider SwiftUI for iOS-first secure Bonjour/WSS/Keychain work; retain RN if Android is approved. | Native code compiles against SDK only after successful simulator build; QR UX, runtime trust, physical phone and RN comparison remain open. |
| ADR-C11 — Host browser baseline | Use macOS Chrome for interaction/runtime discovery without treating it as target playback evidence. | Host landing-page and generic input checks exist; target Chromium/compositor, DRM and hardware decode remain open. |

## Remaining feasibility gates

| Gate | Status |
|---|---|
| Rustup resolution and compiler pin | **PASS in login shell.** Use `zsh -lc`; non-login PATH selection can still resolve Homebrew Rust. |
| Debian 12 ARM64 Rust smoke build / ELF | **PASS for the disposable smoke artifact only.** Pi execution remains blocked. |
| Package installation simulation and dependency review | **PARTIAL.** Chromium+Cage and PipeWire APT plans simulated with no changes; labwc candidate unavailable in bookworm and no Widevine candidate found. See `PHASE0B_PACKAGE_REPORT.md`. |
| macOS Chrome host-first runtime smoke | **PARTIAL PASS.** Core lifecycle and generic inputs pass; Fullscreen API, media key and media seek are individually recorded. No provider playback. |
| iOS SwiftUI/native networking spike | **PARTIAL.** Library and shell build passed for Simulator SDK; simulator installation timed out, so app launch, local network permissions and physical device behavior remain blocked. See `evidence/phase0b/ios-swift/simulator-smoke.json`. |
| HDMI detection and display mode | **NOT RUN.** Both connectors were reported disconnected. |
| Non-root graphical session | **NOT RUN.** |
| Chromium and compositor baseline | **NOT RUN.** |
| Hardware-accelerated video decoding | **NOT RUN.** Driver presence is not proof of decode use. |
| DRM compatibility for reference applications | **NOT RUN.** Provider/browser/license behavior is not established. |
| Memory, CPU, I/O and thermal measurements under playback | **NOT RUN.** |
| Existing workload availability during playback | **NOT RUN.** |
| Native iOS development environment and physical-device trust | **PARTIAL.** Toolchain and simulator SDK are present; prototype build status is in host-first evidence; no physical iPhone test or signing. |
| Secure local networking and pairing spike | **PARTIAL source spike only.** Bonjour, QR-provisioned certificate pinning, WSS bearer header, and Keychain APIs are represented; end-to-end pairing and wrong-identity runtime rejection are unverified. |

The Phase 0 review must assess these gates and the relevant ADR candidates before Phase 1 architecture is ratified. Do not begin Phase 1 or full product implementation until the owner approves that review.
