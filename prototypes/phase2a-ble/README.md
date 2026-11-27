# Phase 2A BLE echo experiment

Disposable local experiment for one Mac peripheral and one iPhone central. The UUIDs and payloads are experimental. Use only synthetic data. This is not an authenticated channel.

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

In Xcode, select the Central target, choose your development team under Signing & Capabilities, and use a unique bundle identifier if necessary. Select the connected personal iPhone as the run destination and run the Central scheme. Complete any device trust or Developer Mode prompts presented by Apple. Allow Bluetooth access. These steps require a development account and device authorization; neither has been verified here.

With the Mac advertising, the central scans automatically. Once subscribed, tap **Send test** and inspect the numbered notification in both windows. Tap **Disconnect**, then **Scan** to reconnect. A write acknowledgement is a GATT result, not an authenticated application acknowledgement.

The peripheral accepts one subscriber for this experiment and bounds its pending notification queue to 16 messages. It rejects payloads larger than the subscriber's reported notification limit or 128 bytes. The iOS app permits one write with response at a time. No fragmentation, persistence, security or automatic reconnection is implemented. Actual device behavior has not been verified.
