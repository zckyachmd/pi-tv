# Phase 2A build checkpoint

Date: 2026-11-27. Host: macOS arm64; Xcode 27.2 (27B52), Apple Swift 6.4.2.

- PASS: `xcodebuild -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Peripheral -configuration Debug -derivedDataPath prototypes/phase2a-ble/build CODE_SIGNING_ALLOWED=NO build` — exit 0, BUILD SUCCEEDED.
- PASS: `xcodebuild -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -configuration Debug -sdk iphoneos -derivedDataPath prototypes/phase2a-ble/build CODE_SIGNING_ALLOWED=NO build` — exit 0, BUILD SUCCEEDED.
- NOT_RUN: application launch, signing, installation, physical BLE and reconnect tests.
- NOT_OBSERVABLE: negotiated payload sizes and radio behavior without running the apps on physical devices.

Builds are unsigned and do not establish development signing availability or physical communication.
