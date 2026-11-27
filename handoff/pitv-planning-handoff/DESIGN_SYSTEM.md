# Pi TV design system — proposal v0.1

## Reference and intent
Original restrained visual identity: dark, solid surfaces, high contrast, crisp focus; avoid copying Google TV, Apple TV or provider branding. Use Android TV focus/ten-foot guidance for TV, Apple HIG for native iPhone, shadcn/ui semantic CSS token model for web; these are reference patterns, not licensed asset bundles. `design-tokens.json` is a candidate starting point; verify contrast and real TV legibility before approval. Use system fonts (no embedded commercial fonts). No gradients, radial halos, blur, video backgrounds, heavy shadows, unnecessary motion or external asset requests in launcher. Provider icons require explicit rights review; start with text labels/generic category symbols.

## Token model
One versioned canonical JSON for primitive/semantic color, spacing, radius, motion and platform typography. Deterministic generated CSS variables/Swift constants or small mapping layer with drift tests. Do not hardcode hex/radius/spacing in feature components; semantic roles and named variants. Platform typography and sizing may differ intentionally; SwiftUI dynamic type, safe areas, native navigation and system appearance. TV dark theme default, iOS system light/dark; light palette must be contrast-tested. State indicators always text/icon + color. Use restrained solid focus border; minimum 3:1 contrast for focus and controls, 4.5:1 for normal text, 3:1 large text (WCAG AA). Validate actual foreground/background combinations.

## TV surface
1920x1080 design baseline, test 1280x720 and overscan/safe margin (candidate 5%); text hierarchy title 48px, section 32px, body 24px, metadata 20px; 4/8 grid, large cards, no tiny click targets. D-pad spatial algorithm uses geometry and row/column intent; up/down must not equal left/right. Deterministic focus, disabled skip, preserve last focus after returning, modal focus trap and restoration, prevent focus theft during typing/scrolling, no dead ends; wrap only by explicit policy. All own UI works keyboard-only; third-party web pages may require touchpad. Keep launch screen fast, show actionable errors instead of blank screen; status bar not continually animated.

## iOS surface
Native SwiftUI, 44x44 pt minimum interactive hit area, VoiceOver labels/hints and adjustable Dynamic Type, Reduce Motion support, accessibility identifiers, haptics optional and respect user setting. D-pad primary, touchpad mode with explicit sensitivity and scroll; media controls shown from actual capability event, volume set/mute, home/back, keyboard modal with explicit sensitive text rules. No optimistic 'playing' when state unknown. Use system navigation and sheets, consistent error and pairing state. Don't force TV's pixel typography onto iPhone.

## Required screen flows (wireframes before implementation)
| Surface | Screens | Required states |
|---|---|---|
| TV | First boot, home/app grid, app details/launch, pairing QR, device approval, settings/paired devices, diagnostics, recovery | empty, loading, focus, busy, unsupported app, offline, QR expired, success, permission/revocation, crash recovery |
| iOS | Welcome/Bluetooth permission, scanner, discovered devices, verification/pair confirmation, remote, touchpad, keyboard, device list/settings, help | radio off, denied, not found, connecting, authenticating, paired, disconnected, stale state, busy, unsupported capability, revoked, wrong identity, QR invalid/expired |

## Component catalog
TV: AppTile, FocusRing, AppGrid, PageHeader, StatusText, Dialog, PairingCodePanel, SettingsRow, ErrorPanel, LoadingState. iOS: DeviceRow, ConnectionStatus, DPad, RemoteButton, Touchpad, MediaControls, VolumeControl, KeyboardSheet, PairingScanner, PairingResult, ErrorBanner. For each define anatomy, semantic tokens, variants, sizes, default/focused/pressed/disabled/loading/error states, accessibility behavior, event semantics, example, tests. Prefer native controls on iOS, accessible HTML on TV. No blanket installation of component libraries; assess size and accessibility first.

## Quality gate
Design acceptance: approved flow map, screen inventory, annotated wireframes for both surfaces, token source, component/state matrix, focus graph, accessibility checklist, performance budget. Visual regression at 720p/1080p and iPhone sizes with light/dark/Dynamic Type; stable snapshots, no arbitrary thresholds without evidence. Playwright focus graph and keyboard-only tests; XCTest/SwiftUI accessibility smoke. Real TV distance and actual iPhone testing. Candidate launcher <=200 KiB compressed JS, report raw size and parse/render overhead, no continual animation or polling, reduced motion disables transitions. Design assets and source attribution in docs. No Figma account or external assets required; if desired, later build a Figma library from approved tokens. This file is not a finished visual mockup or a brand clearance.

Refs: https://developer.android.com/design/ui/tv/guides/styles/focus-system ; https://developer.android.com/develop/adaptive-apps/guides/tv/build-adaptive-apps-for-tv ; https://developer.apple.com/design/human-interface-guidelines/accessibility ; https://ui.shadcn.com/docs/theming ; https://www.w3.org/TR/WCAG22/ .
