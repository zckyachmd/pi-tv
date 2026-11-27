# Session 2A physical verification checkpoint

Status: **physical BLE checkpoint passed; Session 2A incomplete**. Evidence: [physical checkpoint](../../evidence/phase2a/physical-checkpoint.md) and [unsigned build checkpoint](../../evidence/phase2a/build-checkpoint.md).

F-20: **incomplete**. A physical iPhone and development signing identity are available; the earlier preflight left design validators and other checks incomplete.

F-21: **PASS** for the basic physical BLE path. The signed app installed; after the owner completed device trust, the iPhone connected and exchanged numbered payloads with the Mac. Reconnect and one exchange with USB disconnected and iPhone Wi-Fi and cellular disabled were observed or reported. This does not establish bounded transport behavior, reliability measurements, or Raspberry Pi compatibility.

| Case | Result |
| --- | --- |
| Mac peripheral powered state and service registration | PASS: advertising path follows powered-on state and successful service-add callback |
| Mac advertising callback | PASS: application displayed Advertising; over-the-air discovery not established |
| iPhone installation | PASS: signed application installed; earlier unsigned installation rejected |
| iPhone launch | PASS: owner reports Central connection status and Mac observed subscription |
| Discovery, connection, characteristic discovery, subscription | PASS: iPhone reported connection and Mac observed subscription |
| Write with response, echo, repeated exchange | PASS: Mac observed two writes; owner confirmed acknowledgements and matching notifications on iPhone |
| Disconnect cleanup, reconnect and subsequent exchange | PASS: Mac observed queue cleanup, resubscription and echo 3; owner confirmed acknowledgement and matching notification |
| Wi-Fi and cellular disabled, Bluetooth enabled | PASS: owner reported settings and matching echo 4 without error; Mac observed resubscription and receipt |

F-22: **NOT_RUN**, pending a working physical BLE path. No throughput, latency, negotiated payload or reconnect measurements have been collected. Proceed to F-22 bounded transport and its tests only after reviewing this checkpoint. Do not advance to Session 2B until the Session 2A gate is met.

## BLE-01 and BLE-02 regression checkpoint (2026-11-27)

Source state: working tree based on `6c991b4d38987d5e025e5454673cf12b1e19487a`, including the pre-existing project signing configuration and the uncommitted peripheral and test changes. BLE-01: corrected in source; the batch receives one decision and the callback responds once to its first request, after complete admission validation. BLE-02: corrected in source for subscription ownership, write admission, targeted notifications, unsubscribe and radio-loss cleanup. Peer identifiers route traffic; they do not authenticate a peer. CoreBluetooth peripheral cleanup relies on its unsubscribe and radio-state callbacks; physical multi-peer behavior has not been verified.

Commands run from the repository root:

- `swiftc prototypes/phase2a-ble/Mac/PeerQueue.swift prototypes/phase2a-ble/tests/main.swift -o /tmp/pi-tv-peerqueue-tests && /tmp/pi-tv-peerqueue-tests` — exit 0; deterministic admission, contention, queue preservation and cleanup assertions passed.
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Peripheral -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build` — exit 0.
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` — first exit 65 because concurrent builds locked the shared build database; sequential retry exit 0, with orientation and launch-screen warnings.

No hardware was accessed. Tests exercise the shared queue model, not CoreBluetooth callback delivery or actual radio backpressure. Session 2B remains locked.

## Session 2A.3.2 — incomplete implementation checkpoint

BLE-03 and BLE-04 remain **incomplete**. Initial lifecycle and echo models are integrated into the Central prototype, but have not met the requested regression coverage or lifecycle guarantees. In particular, CoreBluetooth write acknowledgements do not identify a request or connection generation, and stale callbacks for the same peripheral cannot always be distinguished; a late acknowledgement may be misattributed. Mismatched notifications are currently logged as stale or mismatched rather than producing a distinct terminal mismatch. Do not use these changes as evidence of reliable correlation. Physical verification remains outstanding.

Experimental deadlines are 15 seconds for connection, 10 seconds each for service discovery, characteristic discovery and subscription, and 10 seconds for the combined request; these are initial bounded diagnostic values, not measured device limits. The combined deadline does not yet provide independently timed acknowledgement and echo phases. Transport ready denotes GATT availability only.

Working tree based on `6c991b4d38987d5e025e5454673cf12b1e19487a`; modified Central, project file and lifecycle test/model in addition to the earlier BLE-01/02 changes. Existing signing settings remain in place.

- `swiftc prototypes/phase2a-ble/iOS/Lifecycle.swift /tmp/pi-tv-lifecycle-tests/main.swift -o /tmp/pi-tv-lifecycle-tests/run && /tmp/pi-tv-lifecycle-tests/run` — exit 0; 19 smoke assertions, incomplete requested coverage. The test source is saved at `prototypes/phase2a-ble/tests/lifecycle/main.swift`.
- `swiftc prototypes/phase2a-ble/Mac/PeerQueue.swift prototypes/phase2a-ble/tests/main.swift -o /tmp/pi-tv-peerqueue-tests && /tmp/pi-tv-peerqueue-tests` — exit 0.
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Peripheral -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build` — exit 0.
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` — exit 0.

Earlier Central build warnings about orientation and missing launch screen describe prototype presentation limitations; assess supported orientations and provide a launch screen before distribution. No warning was suppressed. No hardware was accessed.

### Follow-up: fail-closed request handling

The earlier ambiguity and mismatch findings above are superseded in the working tree. A request timeout, write error, or mismatched echo now invalidates the connection and starts a ten-second disconnect deadline. Sending remains disabled while disconnecting or failed; a confirmed disconnect permits explicit scanning and fresh discovery. If confirmation is missing, the connection remains failed and the app must be explicitly restarted or receive a later disconnect confirmation. Requests are not replayed. Mismatch is a terminal request outcome visible in the UI. CoreBluetooth callbacks carry no application generation: same-peripheral callbacks cannot be uniquely attributed by generation, and the fail-closed policy limits reuse after ambiguous outcomes rather than proving callback provenance.

Verification from repository root (all exit 0):

- `swiftc prototypes/phase2a-ble/iOS/Lifecycle.swift prototypes/phase2a-ble/tests/lifecycle/main.swift -o /tmp/pi-tv-lifecycle-tests/run && /tmp/pi-tv-lifecycle-tests/run` — deterministic lifecycle and echo assertions, including both callback orders, timeouts, mismatch, late/duplicate events, disconnect deadline and reconnection.
- `swiftc prototypes/phase2a-ble/Mac/PeerQueue.swift prototypes/phase2a-ble/tests/main.swift -o /tmp/pi-tv-peerqueue-tests && /tmp/pi-tv-peerqueue-tests` — existing queue regression assertions.
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Peripheral -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -quiet -project prototypes/phase2a-ble/Phase2A.xcodeproj -scheme Central -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

These are synthetic model tests and unsigned builds, not physical observations. Physical lifecycle and multi-peer verification remains outstanding; Session 2B remains locked.

### Independent review of `4ce32a0be48a506724872b90d266d909488f0832`

BLE-01 and BLE-02: accepted by static review. BLE-03 and BLE-04: partially validated; the prior follow-up does not establish correct application lifecycle integration. Outstanding findings:

- **BLE-07:** `Central.clear()` retains the active `EchoRequest`; unsuccessful terminal requests can prevent sends after reconnect.
- **BLE-08:** `checkDeadlines()` repeatedly processes old terminal timeout outcomes and can invalidate disconnected or newer connections.
- **BLE-09:** reconnect tests construct a request directly and bypass application admission and cleanup.
- **BLE-10:** notification subscription loss while ready is ignored.
- **BLE-11:** confirmed connection establishment failure takes an inappropriate disconnect-wait path.
- **BLE-12:** the active README and this completion summary require reconciliation with existing physical evidence.

BLE-07 through BLE-11 must be corrected and regression-tested before fragmentation is integrated into either application in Session 2A.3.4. They do not block the independent Rust–Swift model. Preserve the historical observations above; Session 2B remains locked.

## Session 2A.3.3 — independent fragmentation model (2026-11-27)

Implemented isolated Rust and Swift models and a directly shared, dependency-free fixture corpus under `prototypes/phase2a-ble/transport/`. No CoreBluetooth integration was attempted. The 13-byte version-1 header is version (1 byte), message ID (4), fragment index (2), count (2), logical length (4), followed by payload; multibyte values are big-endian. The exact policy, terminal errors, reset requirements and layout are in the transport README. It is experimental, not a ratified production protocol.

The maximum logical message is 4096 bytes; each peer may reserve two messages and 8192 declared payload bytes, with a 16384-byte global reservation budget. These values allow two maximum messages per peer and four globally. They bound declared payload reservations, not all process heap overhead. Peer metadata is bounded to 32 entries and 64 UTF-8 bytes per identifier. The caller must provide actual fragment capacity, monotonic milliseconds and expiry polling. Tests do not establish physical BLE behavior or authentication.

Commands from the repository root and final exit codes:

- `cargo test --manifest-path prototypes/phase2a-ble/transport/rust/Cargo.toml -- --nocapture` — exit 0; 2 Rust tests, including 50 shared fixture operations and counter exhaustion.
- `swiftc prototypes/phase2a-ble/transport/swift/Fragment.swift prototypes/phase2a-ble/transport/swift/main.swift -o /tmp/pi-tv-fragment-tests && /tmp/pi-tv-fragment-tests prototypes/phase2a-ble/transport/fixtures/cases.txt` — exit 0; 50 shared fixture operations and counter exhaustion.
- `swiftc prototypes/phase2a-ble/iOS/Lifecycle.swift prototypes/phase2a-ble/tests/lifecycle/main.swift -o /tmp/pi-tv-lifecycle-tests/run && /tmp/pi-tv-lifecycle-tests/run` — exit 0; existing lifecycle and echo regression assertions.
- `swiftc prototypes/phase2a-ble/Mac/PeerQueue.swift prototypes/phase2a-ble/tests/main.swift -o /tmp/pi-tv-peerqueue-tests && /tmp/pi-tv-peerqueue-tests` — exit 0; existing queue regression assertions.

Both implementations matched the same expected encoded bytes and decode outcomes in the shared corpus, including minimum capacity, maximum size, invalid frames, ordering, expiry, budgets and disconnect cleanup. An initial corpus run failed because the global budget remained intentionally full before a later reset case; the fixture now releases it and both final runs pass. BLE-07 through BLE-11 remain prerequisites for application integration, and BLE-12 remains open. No hardware, signed builds or physical tests were performed in this checkpoint.
