# Development host and physical test prerequisites

For PRD v0.1, 27 November 2026. Host sizes below are recommendations, not vendor minimums. Rust 1.100.0 is pinned by this repository and available through rustup in login shells; non-login shell PATH still resolves Homebrew Rust first, so use the supplied host-first scripts or explicit rustup-managed Cargo path. Linux product-daemon ABI compatibility remains unverified. See `PHASE0B_HOST_FIRST_REPORT.md` for evidence.

## 1. Primary development host — macOS

Recommended: Apple Silicon Mac, 16 GB RAM (32 GB more comfortable), at least 80–100 GB free SSD, supported macOS for current App Store-compatible Xcode. Intel Mac only if supported by chosen Xcode and simulator; macOS is required for local iOS builds. Linux can build core and web, but cannot replace macOS for native iOS signing/build/debug. Managed macOS build service is optional; production app must not depend on it.

Install from official sources:
- Xcode full installation, iOS SDK/simulator runtime, command-line tools; select Xcode and accept license through Apple's normal workflow. Apple ID, development signing team; paid Apple Developer Program for TestFlight/App Store distribution. Physical modern iPhone with Developer Mode enabled when required, trusted USB connection or supported wireless debug.
- Git, Rust via rustup (Rust 1.100.0 pinned in `rust-toolchain.toml`), cargo, rustfmt, clippy; Node.js active LTS and project-pinned pnpm (via supported installation method), Python 3 for benchmark scripts, SSH, jq, curl, OpenSSL, rsync, and optional Homebrew for host tools. Keep `$HOME/.cargo/bin` before Homebrew in PATH so rustup proxies honor the project pin. Native Rust Linux binary must be built for Linux, not macOS ARM64.
- Expo/RN development build after compatibility spike; pin matching Expo SDK, React Native, React, Node and Xcode combination from official docs. Expo Go cannot prove custom native trust/discovery. CocoaPods only if selected build tooling requires it; don't install global unpinned JS tooling as a project requirement. Install simulator only as needed.
- Docker/VM optional on **development host only** for Linux build/test. Preferred ARM64 Linux native CI runner/VM with a distro/sysroot matching reference OS; verify glibc ABI and package installation on Pi. QEMU can help test userspace, never substitutes GPU/DRM/thermal testing.

Host inventory (read-only):
```bash
sw_vers
uname -m
xcodebuild -version
xcode-select -p
xcrun --sdk iphoneos --show-sdk-version
xcrun simctl list devices available
git --version
rustup show
rustc -Vv
cargo --version
node --version
pnpm --version
python3 --version
ssh -V
df -h .
```
Use `xcode-select --install` only if CLT absent; full Xcode installed separately. Exact latest SDK requirements should be checked on Apple submission page; SDK requirement and minimum device OS are different. Apple documents iOS 26 SDK requirement effective April 28 2026, while its current submitting page refers to SDK 27; verify effective rule and supported stable Xcode at implementation/release rather than pin from stale guidance. Proposed device deployment minimum iOS 18, contingent on chosen framework and owner confirmation.

## 2. Linux build host / CI

Recommended Debian-compatible x86_64 or ARM64 machine, 8 GB RAM minimum recommended (16 GB preferred), 30–50 GB free disk. Build in reference ARM64 environment or cross-compile from a pinned matching sysroot. On Debian family, candidate host packages (verify names first):
```bash
sudo apt update
sudo apt install build-essential pkg-config git curl ca-certificates \
  python3 jq openssh-client rsync dpkg-dev lintian
```
Cross-build only when needed: matching `gcc-aarch64-linux-gnu`, binutils and target sysroot; `rustup target add aarch64-unknown-linux-gnu`; configure linker and native dependencies explicitly. Do not install arbitrary cross libraries or mix distro versions. Use Cargo.lock, `cargo build --locked --release --target aarch64-unknown-linux-gnu`; exact packaging command defined after Phase 0. Install cargo-deb/nextest/audit/deny as pinned host/CI tools when justified, not on target device. Use Linux VM/runner for Debian package tooling if macOS primary host. CI may use platform-appropriate runner; isolate secrets, signing and protected release environments.

## 3. Physical reference Pi 4B (1 GB)

Required: actual 1 GB board, quality 5V/3A USB-C supply suitable for Pi 4, adequate heatsink/ventilation, micro-HDMI to HDMI cable, TV/display and audio, separate test storage (recommended 32 GB or larger quality microSD or compatible USB SSD), working LAN with DHCP, Ethernet preferred for reproducible benchmarks, Wi-Fi for secondary tests, SSH access with key authentication. Keep existing Debian storage intact; backup or spare media before any OS change. No router port forwarding. USB keyboard optional for local emergency recovery. No Node/Rust/C++ development stack, Docker, database server or full desktop on certified target. Install only runtime dependencies required by selected package and optional benchmark tools temporarily.

Use supported Raspberry Pi OS Lite ARM64 as reference. Existing Debian can be tested non-destructively. Use Raspberry Pi Imager and official checksums for spare media; user creates unique SSH credentials, enables network/SSH through supported provisioning. Package candidates: Chromium from supported OS repo, labwc or Cage (one compositor active), Avahi daemon, D-Bus/session components and audio runtime only as required, OS firmware/Mesa dependencies; exact names and versions after `apt-cache policy`. Widevine only through lawful supported provisioning if available for architecture; no proprietary binary copied from random source. Use a dedicated graphical session/service account, not SSH shell as production graphical session. Verify actual session/seat, display/audio and browser sandbox.

Read-only initial inventory over SSH or local terminal:
```bash
printf 'Model: '; tr '\0' '\n' </proc/device-tree/model
cat /etc/os-release
uname -a
uname -m
getconf LONG_BIT
free -h
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
df -h
ls -l /dev/dri /dev/snd
systemctl --version
stat -fc %T /sys/fs/cgroup
systemctl --failed
systemctl list-units --type=service --state=running
ip -brief address
apt-cache policy chromium chromium-browser labwc cage avahi-daemon
command -v vcgencmd && vcgencmd measure_temp
command -v vcgencmd && vcgencmd get_throttled
```
Do not publish network addresses, hostnames, SSH keys or secrets in public logs. Missing commands/paths are observations, not instructions to change OS. Measure clean baseline before installing candidate browser. Use `/proc/meminfo`, `/proc/pressure/{memory,cpu,io}`, cgroup memory accounting, `/proc/<pid>/smaps_rollup` (permissions permitting), `vmstat 1`, and browser diagnostics/YouTube stats. Ensure test instrumentation overhead recorded; never infer GPU decoding solely from codec advertised by hardware. Use provider accounts manually, with license and user consent; do not automate sign-in or capture credentials. No remote debugging on LAN.

## 4. iPhone / networking

Physical iPhone on same LAN as Pi, proposed iOS 18+ and a current release test; exact model/version must be recorded. Allow local network access at onboarding, test permission denial and re-enable. Test Bonjour, address change, IPv4/IPv6 where available, no internet with LAN still up, AP isolation (expected actionable failure), background/lock then resume, paired/unpaired device and TLS wrong fingerprint. Simulator helps UI and unit tests but cannot certify local network privacy behavior. Test with device trust, Developer Mode and native development build; use Keychain, not JS plaintext storage. QR camera permission only when necessary; manual pairing fallback must still authenticate device.

## 5. Setup readiness checklist

- [ ] Repo created or supplied; clean branch and git identity configured.
- [x] Primary host inventory and selected Rust toolchain version saved; Rust 1.100.0 is pinned in `rust-toolchain.toml`. Login-shell rustup selection is verified; non-login PATH consistency still needs cleanup.
- [x] Xcode 27.2 and iPhoneOS SDK 27.2 detected; a Swift networking/security library compiles for the iOS Simulator SDK. App signing, app-shell build, simulator runtime behavior and physical iPhone readiness remain unverified.
- [ ] Pi 4B 1 GB inventory captured; spare media and recovery path ready.
- [ ] Pi network/HDMI/audio/power confirmed; independent SSH recovery available.
- [ ] Provider accounts/test content available where required; no secrets stored in repository.
- [ ] Benchmarks can be repeated with same conditions and versioned scripts.
- [ ] No automatic destructive setup without explicit authorization.

References: https://developer.apple.com/xcode/system-requirements/ ; https://developer.apple.com/app-store/submitting/ ; https://developer.apple.com/news/upcoming-requirements/?id=04282026a ; https://docs.expo.dev/versions/latest/ ; https://docs.expo.dev/develop/development-builds/introduction/ ; https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy ; https://www.raspberrypi.com/software/operating-systems/ ; https://doc.rust-lang.org/stable/rustc/platform-support.html
