# Experimental fragment model

This isolated, unauthenticated model is not a ratified protocol and is not connected to CoreBluetooth. The caller supplies the actual maximum characteristic value capacity; there is no fixed ATT MTU. Capacity must be at least 14 bytes. Empty messages are rejected.

Version 1 has a 13-byte header, followed by at least one payload byte. All multibyte fields are unsigned, big-endian:

| Offset | Bytes | Field |
| --- | --- | --- |
| 0 | 1 | Version, exactly 1 |
| 1 | 4 | Message ID, 1 through 4294967295 |
| 5 | 2 | Zero-based fragment index |
| 7 | 2 | Nonzero fragment count |
| 9 | 4 | Total logical message length, 1–4096 bytes |
| 13 | remaining | Fragment payload |

A sender starts at ID 1 and never wraps; after issuing the maximum ID, the next send fails terminally. A receiver accepts new IDs strictly greater than the last started ID for that peer, and permits at most two messages to interleave. Each message must begin at index zero and continue in strict index order with the same count and length. Duplicate, conflicting, reordered, malformed, impossible-length and expired sequences fail the peer transport; no partial message is emitted. Missing fragments are detected when the caller invokes expiry or supplies another frame at or after the three-second deadline. A monotonic millisecond reading is supplied by the caller; a clock moving backwards also expires the sequence. Reset on disconnect discards the peer's pending state and permits IDs to start over. The caller must discard old-connection fragments and explicitly handle terminal failures; the model cannot identify a connection generation.

The receiver reserves each declared logical length before buffering. The per-peer budget is 8192 bytes (two maximum messages), and the global budget is 16384 bytes (four maximum messages). Reservations are released on completion, failure or reset. These are logical payload budgets, not exact process heap limits: frame inputs, sender output, collection capacity and metadata have additional overhead. To bound metadata, peer identifiers are limited to 64 UTF-8 bytes and the receiver retains at most 32 peers, including failed peers until reset. Exceeding either metadata limit fails the whole receiver until `reset_all`/`resetAll`; ordinary protocol failures fail only the affected peer until reset. No security or peer authentication is provided. Caller polling, transport loss detection, delivery acknowledgements, backpressure and physical BLE behavior remain unproven.

`fixtures/cases.txt` is the common corpus: each line is an encode, receive, expiry or reset operation, with expected bytes or outcomes. Both standard-library implementations consume it directly. The fixture data is synthetic.
