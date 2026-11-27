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
| Synchronizing | Transport is connected and authentication succeeded; obtain authenticated capabilities and a current state snapshot. Commands remain disabled. |
| Ready | The peer identity is authenticated and authorized, and authenticated capabilities and an authoritative current state snapshot have been synchronized for this session. Enable only supported controls. |
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

Transport, authentication, synchronization, runtime and command results are independent dimensions. Loss or invalidation of authentication, capabilities, or the current snapshot exits Ready and disables control until synchronization succeeds again. Runtime application status and individual command outcomes do not establish readiness.

## Independent dimensions and readiness

| Dimension | Representative values | Ownership and effect |
|---|---|---|
| Transport | unavailable, disconnected, connecting, connected | Radio/link only; connected does not establish identity. |
| Authentication | unauthenticated, authenticating, authenticated, revoked | Session verifies identity and authorization; revoked requires new enrollment. |
| Synchronization | unknown, synchronizing, current, stale | Authenticated capabilities and authoritative snapshot for the current session and revision; revision gap or session loss makes it stale. |
| Runtime | idle, launching, running, failed, unknown | Core reports application lifecycle; independent of radio state. |
| Command | idle, accepted, applied, failed, outcome unknown | Per command, not a session state; unknown requires reconciliation. |

Ready is derived only when transport is connected, the peer identity is authenticated and authorized, and required authenticated capabilities and authoritative state are current for that session. On session loss, revision gap or invalidation, leave Ready immediately; reauthenticate and synchronize before enabling controls. A ready session may still have unavailable or unsupported individual actions.
