# Phase 2A BLE echo experiment

Disposable local experiment for one Mac peripheral and one iPhone central. The UUIDs and payloads are experimental. Use only synthetic data. This is not an authenticated channel.

Session 2A is conditionally closed after independent review of `7b11d833275067d129c4d4198b1ac981757820ff`: F-21 passed for the tested Mac–iPhone path and F-22 was functionally validated with measurements still open. The Central includes a bounded benchmark and exports partial JSON results; failed requests stop the batch and require a fresh transport context. Use only one Peripheral instance and verify it is the current build before measuring. An earlier run had an ambiguous peer; see the [checkpoint](../../docs/planning/session-2a-completion.md) for its disposition and the later verified runs. The observed successes do not establish deadline suitability across all conditions.

## Build and launch the Mac peripheral

From the repository root:

```sh
xcodebuild -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Peripheral -configuration Debug -derivedDataPath prototypes/phase2a-ble/build CODE_SIGNING_ALLOWED=NO build
open prototypes/phase2a-ble/build/Build/Products/Debug/Peripheral.app
```

Allow Bluetooth access when prompted. The window reports advertising and events. Keep the app open in the foreground.

## Build and install the iPhone central

The following builds an unsigned device app; it cannot be installed on a physical iPhone without signing:

```sh
xcodebuild -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -configuration Debug -sdk iphoneos -derivedDataPath prototypes/phase2a-ble/build CODE_SIGNING_ALLOWED=NO build
open prototypes/phase2a-ble/Phase2A.xcodeproj
```

In Xcode, select the Central target, choose your development team under Signing & Capabilities, and use a unique bundle identifier if necessary. Select the connected personal iPhone as the run destination and run the Central scheme. Complete any device trust or Developer Mode prompts presented by Apple. Allow Bluetooth access. A signed fragmented Central and Mac Peripheral were used in the later physical checkpoint; exact tested binary provenance remains unresolved.

With the Mac advertising, the central scans automatically. Once subscribed, select 64, 256, 1024 or 4096 bytes, tap **Send test**, and inspect the logical echo result. Tap **Disconnect**, then **Scan** to reconnect. A write acknowledgement is a GATT result, not an authenticated application acknowledgement.

The peripheral accepts one subscriber; its identifier is a routing key, not an authenticated identity. Each direction sends one logical record at a time using the experimental 13-byte fragment format described in [transport/README.md](transport/README.md). The central sends one fragment per write acknowledgement. The peripheral sends notifications incrementally and retains its current frame when CoreBluetooth applies backpressure. A matching complete echo and all fragment write acknowledgements are required for success; a write acknowledgement alone is not an application result. Failures are not replayed.

The earlier raw echo path was exercised on an iPhone and Mac as recorded in [the physical checkpoint](../../evidence/phase2a/physical-checkpoint.md). Subsequent current-pair fragmented measurements and their limitations are recorded in the [2A.3.5 checkpoint](../../docs/planning/session-2a-completion.md). CoreBluetooth callback attribution and broader deadline suitability remain unverified. No authentication, encryption or automatic reconnection is implemented.
