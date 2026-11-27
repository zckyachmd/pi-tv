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
