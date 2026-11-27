# UX flows

Proposed for review. Screen IDs refer to the [inventory](SCREEN_INVENTORY.md); state names and independent dimensions are defined in the [state model](UI_STATE_MODEL.md). Local enrollment, its trusted input and any existing-controller authority remain subject to owner and security approval. These diagrams describe conditional UX, not approved security mechanisms. [Protocol](../architecture/BLE_PROTOCOL.md) and [recovery](../architecture/RECOVERY.md) govern the proposed boundaries.

## 1. First boot and secure enrollment

```mermaid
flowchart LR
 A[TV-01 Local provisioning] -->|approved local mechanism| B[TV-04 Enrollment QR]
 B --> C[IOS-03 Scan] --> D[IOS-04 Authenticate]
 D --> E[TV-05 Await local confirmation]
 E -->|approved local confirmation and durable commit| F[IOS-05 Select device]
 E -->|reject, expiry or uncertain commit| B
```

The QR is one-use and expires; display is not authorization. Authenticate the intended identity, bind enrollment to the session, and show success only after commit. If no approved local path exists, explain the blocker; do not substitute an unauthenticated phone.

## 2. Normal connection and authenticated control

```mermaid
flowchart LR
 A[IOS-05 Select] --> B[Connecting] --> C[Authenticating]
 C --> D[Synchronizing] -->|identity authorized, capabilities and authoritative snapshot current| E[Ready: IOS-06 or IOS-07]
 E --> F[Command accepted] --> G[Applied / failed / outcome unknown]
 E --> H[IOS-08 Keyboard] --> E
```

Enable only supported controls while Ready. Accepted is queued, applied is the adapter boundary, and neither proves provider playback. Media and volume are capability dependent.

## 3. Bluetooth unavailable and permission denial

```mermaid
flowchart LR
 A[IOS-01 Welcome] --> B{Permission and radio}
 B -->|available| C[IOS-02 Discovery]
 B -->|denied or unavailable| D[IOS-10 Help and settings guidance]
 D -->|user returns and retries| B
```

Explain the specific condition and offer platform settings guidance; do not repeatedly prompt or infer revocation.

## 4. Invalid, expired and wrong-device QR

```mermaid
flowchart LR
 A[TV-04 QR] --> B[IOS-03 Scanner] --> C{Validate and authenticate}
 C -->|invalid, expired, reused or wrong identity| D[IOS-04 Error]
 D -->|retry| B
 D -->|new window via approved local path| A
 C -->|valid and authenticated| E[TV-05 Local confirmation]
```

Fail closed; never display the payload or treat discovery hints as identity. A new QR requires a new approved local window.

## 5. Connection loss, reconnect and synchronization

```mermaid
flowchart LR
 A[IOS-06 or IOS-07 Ready] -->|link loss| B[IOS-10 Disconnected]
 B --> C[Reconnecting] --> D[Authenticating] --> E[Synchronizing]
 E -->|current authoritative snapshot and capabilities| A
 E -->|failure| B
```

Disable commands immediately; release held keys. Playback may continue. Reconcile unknown outcomes rather than replay non-idempotent commands; a revision gap also leaves Ready.

## 6. Adding or replacing a controller

```mermaid
flowchart LR
 A[TV-06 or IOS-09 Management] --> B{Request allowed by policy?}
 B -->|yes, and approved local path available| C[TV-04 New QR]
 B -->|no or undecided| D[TV-10 Local recovery guidance]
 C --> E[IOS-03 Scan] --> F[IOS-04 Authentication] --> G[TV-05 Local confirmation]
 G --> H[TV-06 Manage devices]
```

An existing controller is not assumed to authorize another. Replacement does not automatically revoke the old identity; revoke separately through an authorized path.

## 7. Revocation and all-devices-lost recovery

```mermaid
flowchart LR
 A[TV-06 or IOS-09 Device management] --> B[Authorized revoke confirmation]
 B -->|persisted| C[Revoked; terminate session]
 C --> D[IOS-10 Fresh enrollment required]
 D -->|all devices lost, approved local path| E[TV-10 Recovery] --> F[TV-04 New enrollment]
```

The remote action is offered only if policy authorizes it. Outage alone is not revocation; recovery does not silently erase identity or provider profiles.

## 8. Factory reset

```mermaid
flowchart LR
 A[TV-07 Settings] --> B[Local reset scope and confirmation]
 B -->|cancel| A
 B -->|approved local confirmation| C[Reset in progress]
 C -->|complete| D[TV-01 Provisioning]
 C -->|interrupted or uncertain| E[TV-10 Local recovery]
```

Reset revokes controller credentials and rotates device identity. Settings and provider profiles are erased only when explicitly included and confirmed. Fail closed on interruption; exact authorization and recovery remain gated.

## 9. Application lifecycle and browser recovery

```mermaid
flowchart LR
 A[TV-02 Catalog] -->|launch| B[TV-03 Loading]
 B -->|success| C[Foreground runtime]
 B -->|unsupported/unavailable| D[TV-09 Explanation] --> A
 C -->|browser failure| E[TV-10 Recovery]
 E -->|diagnostics| F[TV-08 Diagnostics] --> E
 E -->|safe retry| B
 E -->|Home| A
```

Runtime lifecycle is independent of session state. Display actionable failure, preserve trusted state and profiles, and avoid claiming provider compatibility or playback without evidence.
