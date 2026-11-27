# Host and test prerequisites — Session 1B proposal

2026-11-27. This replaces the operational guidance in [v0.1](docs/archive/HOST_PREREQUISITES-v0.1.md); Phase 0 reports remain historical. No setup or target access is authorized by this document.

## macOS host

A supported Mac with full Xcode, iOS SDK and simulator, Swift, Git and the repository-pinned Rust toolchain is needed. Check `xcodebuild -version`, `xcrun simctl list devices available`, `rustup show`, `rustc -Vv`, and available disk before work. Resolve non-login PATH to rustup explicitly. Node and a pinned package manager are needed only when the launcher stack is approved. Build Linux ARM64 using a pinned compatible Linux builder/sysroot; inspect ELF dependencies and later execute on the actual OS. Host build success is not Pi execution.

Use simulator for UI and fake-transport tests only. A physical modern iPhone, appropriate signing and camera/Bluetooth permissions are required for radio, pairing and reconnect tests. Mac peripheral-mode support and permission behavior must be proven before depending on a Mac test peripheral; otherwise use a separately authorized test rig. The previously reported simulator install timeout remains unresolved; a simulator build is not a successful app launch.

## Target test gate

Actual Pi 4B 1 GB, safe power/cooling, HDMI and audio, keyboard or independent recovery, compatible storage, and an approved maintenance window are required for target certification. Shared Host tests additionally require a baseline, representative existing workloads, owner-approved limits, recovery and abort thresholds. Do not change services, radio, firewall, swap, packages or storage without separate authorization. Record actual OS, kernel, BlueZ, adapter, D-Bus privileges, firmware, advertising/GATT capability, Wi-Fi coexistence and resource usage. A build host or Mac radio cannot prove these properties.

For controlled future read-only inventory, discover adapter paths rather than assume `hci0`; candidates include `bluetoothctl list`, `bluetoothctl show`, `rfkill list`, `dpkg-query -W bluez` and BlueZ D-Bus introspection. Review output for identifiers before saving. Run only after target access is separately authorized. Existing [`scripts/phase0b/pi-readonly-diagnostics.py`](scripts/phase0b/pi-readonly-diagnostics.py) has not established current target state.

## Remote acceptance setup

A physical iPhone scans the displayed QR and connects over BLE. Test with phone Wi-Fi and cellular disabled and separately with Pi network disconnected for offline functions; online provider playback requires the Pi's independent internet connection. No shared LAN, Bonjour, local-network permission or WSS is an MVP prerequisite. Test denied camera/Bluetooth permissions, radio off, background/foreground, wrong device, expiry, revocation and loss/recovery. Do not assume simulator or macOS tests establish iOS background operation or Pi behavior. Minimum iOS version and signing/distribution approach remain open.

Official references, reviewed 2026-11-27: [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth), [Apple simulator background behavior](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), [Raspberry Pi OS](https://www.raspberrypi.com/software/operating-systems/). Recheck toolchain and platform requirements at implementation time.
