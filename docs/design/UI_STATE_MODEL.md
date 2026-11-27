# UI state model

Proposed, 2026-11-27. This is a presentation vocabulary, not a wire protocol. The session and core remain authoritative; UI focus and radio connectivity confer no authority. See [protocol](../architecture/BLE_PROTOCOL.md) and [recovery](../architecture/RECOVERY.md).

| State | Presentation and permitted action |
|---|---|
| Bluetooth unavailable | Explain radio unavailability; offer platform-appropriate settings guidance. |
| Permission denied | Explain permission and offer settings guidance; do not repeatedly prompt. |
| Discovering | Show progress and cancellation; no control commands. |
| Connecting | Show transport progress; do not call this authenticated. |
| Authenticating | Show session authentication progress; disable commands. |
| Awaiting enrollment confirmation | Ask for confirmation through the approved trusted local path; show expiration and cancellation. |
| Connected and authenticated | Enable only capabilities confirmed by an authenticated snapshot. |
| Disconnected | Explain loss; playback may continue; do not infer revocation. |
| Reconnecting | Show progress; authenticate again and obtain a snapshot before controls are enabled. |
| Revoked | Explain that fresh enrollment is required; do not silently retry credentials. |
| Stale or unknown application state | Label state unknown and request a fresh snapshot; do not present cached state as current. |
| Unsupported capability | Explain unavailable action; never infer support from provider identity. |
| Command accepted | Queued for processing, not completed. |
| Command applied | Confirm only the documented adapter boundary, not provider playback. |
| Command failed | Show a useful failure and action if available. |
| Outcome unknown | Say outcome is unknown and reconcile state; never automatically replay a non-idempotent command. |

These dimensions can coexist: a command result does not replace connection state. Presentation receives sanitized status, public device labels, capabilities, revisions, and bounded results, never cryptographic secrets, enrollment credentials or provider credentials. QR rendering is a narrowly scoped trusted local enrollment operation; avoid logging or exposing its secret to general presentation state.

An existing trusted controller may request enrollment only if policy permits; local confirmation remains required under the current proposal. Whether it may authorize adding another controller remains an owner and security decision, not a UI assumption. Recovery and local enrollment mechanisms are conditional on approval and review.
