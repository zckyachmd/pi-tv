# TV focus graph

Proposed deterministic navigation for the [inventory](SCREEN_INVENTORY.md), applying [TV interaction](TV_INTERACTION.md) and the [component catalog](COMPONENT_CATALOG.md). Only visible enabled controls receive focus; disabled controls retain a readable adjacent reason. One focus ring is visible, including within scroll areas. Asynchronous state changes never steal focus; if the focused item disappears, choose the nearest enabled sibling, then a focusable page-level action. Focus does not confer authorization.

## Shared navigation algorithm

Arrows select visible enabled candidates whose centers lie in the requested half-plane. Prefer perpendicular-axis overlap, then smallest forward edge distance, then perpendicular center distance, then stable visual order. Scroll the chosen control into view. No wrap: if no candidate exists, remain in place. Group transitions below define explicit candidates at boundaries; use the geometric rule when multiple candidates are present. Disabled entries are skipped, never activated. Every screen has a reachable Back or Home action where appropriate.

## Screen transitions

| Screen | Focus nodes and transitions |
|---|---|
| TV-01 | Display-only before authentication; automatically proceed to candidate unowned bootstrap. No focus or Pi input required. |
| TV-02 | Initial focus: restored tile; otherwise first enabled tile; otherwise empty-state action. Left/right moves to the nearest enabled tile in the row, stops at edges. Up/down moves to the nearest enabled tile in the adjacent row, retaining the original column intent across short rows; when no row exists use the nearest enabled header/navigation action in that direction, otherwise stay. Header actions route to TV-04 or TV-07. Activate an available tile → TV-03; unavailable app activation remains disabled; its separate enabled, accessible Details action → TV-09. |
| TV-03 | Initial focus Cancel if enabled; otherwise Home if present. Cancel/Back → TV-02 and restores tile; failure → TV-09 or TV-10 with its initial focus. |
| TV-04 | Display-only before authentication; phone can cancel. QR is not focusable. Renewal follows the applicable reviewed unowned bootstrap or authenticated owner policy; peer pending → TV-05. |
| TV-05 | Display-only comparison before authentication; confirmation or rejection occurs on iPhone under the candidate reviewed ceremony. No focus or TV approval button is required. |
| TV-06 | Initial focus first enabled device row, otherwise Add or Back. Up/down traverse list, then adjacent actions at boundaries; selecting a row opens a dialog with Cancel initial focus. Add → TV-04 only if permitted. Back restores invoking action. |
| TV-07 | Initial focus first enabled settings row. Up/down traverses enabled rows; device management → TV-06, diagnostics → TV-08, reset → confirmation modal. Back → TV-02 and restores invoking action. |
| TV-08 | Initial focus first enabled recovery action, otherwise Back. Up/down traverses actions; recovery → TV-10; Back restores the originating TV-07 or TV-10 screen and its invoking focus. |
| TV-09 | Initial focus Back, or Retry if it is the sole non-destructive enabled action. Up/down moves between actions; Back → TV-02, restoring tile. |
| TV-10 | Initial focus Home when enabled, otherwise first approved local recovery action. Up/down moves through enabled actions; Home → TV-02; Diagnostics → TV-08; recovery guidance → authenticated phone or independent recovery proof; safe Retry → TV-03. |

A modal captures all directional and activation events; directional edges stay inside it. Back cancels only when safe. On dismissal restore the invoking control if visible and enabled; otherwise nearest enabled sibling, then a focusable page heading or page-level action. During reset or an irreversible commit, Back is disabled if cancellation cannot safely be honored and the state is explained.

Text input owns arrow, select and editing keys while active. An explicit Done, Cancel or escape releases ownership and restores focus to its invoking control; navigation does not intercept text editing. A system keyboard is part of this ownership boundary. Home is a separate explicit action outside an active text input; do not silently discard text. Returning Home from runtime restores the last available enabled app tile, else first enabled tile, else the empty-state action. Returning from a modal restores its invoker before any later Home transition.

## Representative acceptance fixtures

| Given | Input | Expected focus/result |
|---|---|---|
| Grid rows `[A,B,C]`, `[D,E]`, all enabled; focus C | Down, Up | E, then C: retain column intent. |
| Same grid, focus A | Left | A; no wrap. |
| Row `[A,B,C]`, B disabled; focus A | Right | C; B cannot activate and its reason remains readable. |
| TV-07 reset row opens confirmation | Activate, Right, Back | Cancel initially; moves only among dialog actions; Back dismisses when safe and returns to reset row. |
| Invoking device row removed while dialog open | Dismiss | Nearest enabled sibling; otherwise focusable page action. |
| Text field active | Left, type, Done | Input receives edit keys; Done releases ownership and returns to invoker. |
| Last Home tile is now unavailable/disabled | Home | First enabled tile, or empty-state action when none exist. |
| TV-10 with Retry disabled and Home enabled | Down/Up | Skip Retry; remain within enabled recovery actions and expose its reason. |
| TV-04 QR expires before authentication | Expiry | Display expired state; no TV input is required and expired QR cannot enroll. |
