# Component catalog

Proposed contracts, not a requirement to create one source file per entry. TV uses accessible HTML; iOS uses native controls where possible. Shared defaults below apply to every entry and the per-entry rows refine them.

**Common contract:** inputs are sanitized display data, explicit state, capability and localized labels; outputs are typed user intentions, never raw protocol frames or credentials. Parent feature owns requests, authoritative state, navigation and errors; components do not authorize, perform transport, infer success or mutate trust. Use `background`, `surface`, `foreground`, `mutedForeground`, `border`, `focus` and appropriate semantic status roles; spacing and radii from tokens. Default, focused (TV), pressed, disabled, loading and error states apply only when meaningful. Focus is not selection, pressed is not success. All interactive elements expose name, role, state and keyboard/VoiceOver operation; color is never the only signal. Disabled items cannot emit actions. Every contract's acceptance test includes the applicable state transitions, accessibility semantics, token use and absence of secret data. TV focus and iOS hit targets follow their platform documents.

| Component | Purpose and anatomy; variants/sizes | Input → event; ownership/composition and restrictions | Specific acceptance |
|---|---|---|---|
| TV AppTile | Label, optional generic icon and secondary text; standard grid tile, default/focused/pressed/unavailable | Public app ID, availability → activate ID; AppGrid owns ordering; no provider support inference | Directional focus visible; unavailable cannot activate and reason is readable. |
| TV AppGrid | Collection of tiles or empty state; responsive columns | Items and focus ID → focus/activate; screen owns data, grid owns spatial arrangement | Uneven rows choose nearest column, restore focus after return. |
| TV FocusRing | Solid outline around focused control; 4 px reference | Focus state → no event; composed by focusable control, never standalone tab stop | ≥3:1 adjacent contrast and visible at both resolutions. |
| TV PageHeader | Heading and optional status/action; one size per type role | Localized title, optional action → action intent; screen composes | Heading semantics and action remain readable at expanded text. |
| TV StatusIndicator | Text plus icon and semantic success/warning/danger/info | Sanitized state → optional action; screen maps session vocabulary | Connected appears only after authentication. |
| TV Dialog | Title, body, actions; confirmation or information | Content and actions → confirm/cancel; feature owns decision | Trap focus, least destructive initial action, restore on close. |
| TV PairingCodePanel | Scoped QR surface, expiry and instructions; active/expired | Trusted enrollment display handle and expiry → cancel; privileged local enrollment owns QR rendering, never general component state or logs | Expired code cannot enroll; no secret appears in diagnostics. |
| TV SettingsRow | Label, value, optional action; single row | Public value and enabled → intent; settings feature owns persistence | Keyboard activation, disabled reason, readable value. |
| TV ErrorPanel | Message and recovery action; error/offline/empty variants | Sanitized error and actions → retry/back intent; screen owns retries | Unknown outcome is not called success or automatically replayed. |
| TV LoadingState | Static progress text and optional cancel | Loading description → cancel; screen owns task | Announce progress without perpetual animation; cancel returns focus. |
| TV RecoveryPanel | Explanation and approved local actions, composed from ErrorPanel/Dialog | Recovery status → local intent; security owner controls authorization | No reset or enrollment confirmation solely from untrusted phone. |
| iOS DeviceRow | Device label, status and optional selected mark; native list row | Public device ID, status → select; device feature owns identity | VoiceOver states selected/revoked; never shows credential. |
| iOS ConnectionStatus | Label and optional recovery action | Session status → settings/retry intent; session owner maps state | BLE link alone never reads authenticated. |
| iOS DPad | Five labeled independent controls; adaptive layout | Enabled/capability → direction/select intent; remote composes RemoteButton | Each target ≥44 pt and usable with VoiceOver. |
| iOS RemoteButton | Native labeled action; normal/destructive as appropriate | Enabled, label → discrete intent; parent owns dispatch | Press feedback does not imply applied result; disabled emits nothing. |
| iOS Touchpad | Gesture area with explicit scroll mode and accessible alternatives | Mode/sensitivity → bounded movement/scroll intent; remote owns coalescing policy | VoiceOver alternative works without gesture; mode is announced. |
| iOS MediaControls | Native play/pause/seek controls; capability-dependent | Observed capabilities → media intent; remote owns results | Unknown or unsupported capability is explained; no provider-state invention. |
| iOS VolumeControl | Minus, mute, plus or native adjustable control | Observed volume/capability → set/mute intent; remote owns state | Adjustable VoiceOver action and 44 pt targets; no optimistic success claim. |
| iOS KeyboardSheet | Native text field, send and cancel; adaptive sheet | Bounded text policy → explicit send/cancel; feature owns sensitive input lifetime | No text logging; focus stays in input; dismissal restores focus. |
| iOS PairingScanner | Native camera permission and scan guidance | Permission and bounded scan result → enrollment request to secure owner; scanner never displays payload | Denied permission is actionable; wrong/expired code fails closed. |
| iOS PairingResult | Status, instructions and next action; pending/success/error | Sanitized result → retry/close; session owns authentication | Pending local confirmation is not success; expired and wrong identity explained. |
| iOS ErrorBanner | Concise error and optional action | Sanitized error → retry/dismiss intent; screen owns policy | VoiceOver announces actionable failure; unknown stays unknown. |

No additional wrapper is required for native controls. PairingCodePanel is a narrowly scoped trusted rendering boundary rather than a general-purpose QR component; the exact mechanism remains security review work.
