# Session 1C.3 — owner wireframe integration

Status: owner review gate. No production implementation, hardware access, package installation, or Session 1C.4 work was performed.

## Artifacts and authority

The [active v2 index](../design/wireframes/v2/README.md) links the owner-supplied TV and iOS indices and [manifest](../design/wireframes/v2/manifest.json). The 70 SVG/PNG pairs comprise 36 TV pairs (10 base screens and eight selected variants at each of two resolutions) and 34 iOS pairs (10 base screens and six selected variants in light and dark, plus two compact previews). Manifest paths were adjusted to the integrated directory; the artwork is unchanged. The snapshot and [canonical tokens](../design/design-tokens.json) are semantically identical at version 1.1.0-proposed. The handoff generator remains in the supplied handoff; no renderer or runtime dependency was added. The earlier [batch A index](../design/wireframes/tv/README.md) is marked superseded; its artifacts, generator and [checkpoint](session-1c3b-batch-a.md) remain historical evidence.

## Reconciliation

[PRD](../../PRD.md), [host prerequisites](../../HOST_PREREQUISITES.md), [recovery](../architecture/RECOVERY.md), [BLE protocol](../architecture/BLE_PROTOCOL.md), [threat model](../architecture/THREAT_MODEL.md), [system design](../architecture/SYSTEM_DESIGN.md), [traceability](../architecture/TRACEABILITY.md), [benchmarks](../architecture/BENCHMARKS.md), [risk register](../architecture/RISK_REGISTER.md), and [security and deployment ADRs](../architecture/adr/README.md) reflect the owner direction. Design updates cover the [screen inventory](../design/SCREEN_INVENTORY.md), [flows](../design/UX_FLOWS.md), [focus graph](../design/FOCUS_GRAPH.md), [state model](../design/UI_STATE_MODEL.md), [component catalog](../design/COMPONENT_CATALOG.md), and TV/iOS interaction documents.

R-01, R-02, R-04, R-05, R-08, R-20 and R-23 are reconciled with first boot, operation, management and recoverable failures using prepared media, the TV and an iPhone over BLE without mandatory extra input, CEC or shared Wi-Fi. R-24 requires prepared media or documented installation; R-25 covers optional authenticated BLE internet provisioning, rollback and shared-host protection. The former independent local HID confirmation requirement and deferred appliance image direction are superseded. TV-01, TV-04 and TV-05 are display-only before authentication.

The bootstrap QR/phone comparison and independently stored recovery kit are **unratified candidates**. QR observation, relay and racing, first-owner atomicity, renewal, corruption, roles, recovery credential protection and rotation, reset and crash semantics need independent security review. Losing all controllers and recovery proof requires maintenance/re-provisioning; fatal hardware or OS faults are outside recoverable application-failure guarantees. If no acceptable secure ceremony is demonstrated, production remains blocked.

## Validation and limitations

Programmatic checks passed: canonical/snapshot JSON equality; 70 unique manifest pairs; SVG XML parsing; SVG and PNG dimensions against the manifest; presence of all ten base IDs per platform; local links in the active and historical indexes; existing token and specification validators; and `git diff --check`. The supplied TV 1080p and iOS light overview sheets were visually inspected for broad screen coverage; this is not individual inspection of all 70 variants. The supplied pack reports its own generation-time text-width and preview checks; those were not rerun here.

Full variant/state coverage, localized long labels, RTL, Dynamic Type, per-element clipping and overlap, actual focus navigation, accessibility and screen-reader behavior remain unverified. Physical iPhone/Pi BLE interoperability, no-HID boot, recovery proof and crash tests, shared-host protection, Wi-Fi setup, HDMI, 1 GB performance and provider/DRM playback remain blocked on separate authorization, hardware and security review. Static designs and sample phrase do not validate the security model or demonstrate provider support.
