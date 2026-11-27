# Physical deployment checkpoint — 2026-11-27

Sanitized observations on the development Mac and connected personal iPhone (iOS 27.2.1). Device and signing identifiers omitted.

- PASS: `xcodebuild -list -project prototypes/phase2a-ble/Phase2A.xcodeproj` (exit 0) lists Peripheral and Central targets and schemes.
- PASS: `xcrun devicectl list devices` (exit 0) reports a connected physical iPhone.
- PASS: `security find-identity -v -p codesigning` (exit 0) reports 0 valid identities.
- FAIL: `xcodebuild -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -configuration Debug -sdk iphoneos -derivedDataPath prototypes/phase2a-ble/build -allowProvisioningUpdates build` (exit 65): `Signing for "Central" requires a development team. Select a development team in the Signing & Capabilities editor.`
- FAIL: `xcrun devicectl device install app --device <redacted> prototypes/phase2a-ble/build/Build/Products/Debug-iphoneos/Central.app` (exit 1): CoreDevice error 3002, installation rejected with `0xe800801c (No code signature found.)`.
- PASS: `open prototypes/phase2a-ble/build/Build/Products/Debug/Peripheral.app` (exit 0); the actual application window displayed `Phase 2A peripheral Advertising`. The application starts advertising after the service-add callback succeeds; this observes the CoreBluetooth callback, not over-the-air discovery.
- NOT_RUN: signed installation, iOS launch, discovery, connection, characteristic discovery, subscription, writes, notifications, repeated exchange, disconnect, reconnect, and offline tests. These depend on signing and installation. No physical payload limits or BLE measurements were observed.

Owner action requested: configure an Apple Development team and identity/provisioning in Xcode for the Central target, using a unique bundle identifier if required. No application source was changed in this checkpoint.

## Follow-up after owner signing

- PASS: signing identity query returned one valid identity (identity omitted).
- PASS: signed `xcodebuild` command above, exit 0, BUILD SUCCEEDED.
- PASS: `xcrun devicectl device install app --device <redacted> <Central.app>`, exit 0, app installed.
- FAIL: `xcrun devicectl device process launch --device <redacted> <bundle>` initially returned CoreDevice error 10002, RequestDenied: invalid signature, inadequate entitlements, or profile not explicitly trusted. `codesign --verify --deep --strict` exited 0 and the embedded profile decoded successfully with development entitlement and registered devices. The owner subsequently reported completing the iPhone trust/open/Bluetooth steps; application UI status is not yet confirmed.
- PASS: Mac window again displayed Advertising; no subscription event was visible at that observation.

## Physical connection observation

The owner reported Central displayed `Connected; maximum write with response: 512 bytes` and `Disconnect before scanning again`. On the Mac, the Peripheral window displayed `Subscribed; maximum notification: 512 bytes`, followed by `Received echo 1; queued 1` and `Received echo 2; queued 1`. This establishes physical connection, discovery, subscription and receipt of two writes; it does not establish write acknowledgements or receipt of notifications by the iPhone. The latter and reconnect are awaiting owner observations.

## Echo and reconnect observations

The owner confirmed the iPhone displayed write acknowledgements and matching `Notification: echo 1` and `Notification: echo 2`. The Mac subsequently displayed `Unsubscribed; pending notifications cleared` followed by a new `Subscribed; maximum notification: 512 bytes`, demonstrating disconnect cleanup callback and resubscription. At that observation no post-reconnect write was visible in the Mac window; its echo remains unverified. The owner was asked to send it and then perform the offline test.

## Post-reconnect and offline exchange

The owner confirmed `Write acknowledged` and matching `Notification: echo 3` after reconnect. The Mac window displayed the unsubscribe and resubscribe events and `Received echo 3; queued 1`.

For the offline test, the owner reported unplugging USB, disabling iPhone Wi-Fi and cellular in Settings, keeping Bluetooth enabled, disconnecting and reconnecting, and successfully sending again. The Mac window displayed another unsubscribe, subscription and `Received echo 4; queued 1`. The owner confirmed `Write acknowledged` and `Notification: echo 4` without error and that Bluetooth remained enabled. The radio settings and iPhone screen were owner-reported, not independently inspected. One offline exchange and one offline reconnect were observed/reported; no reliability or latency distribution is established.
