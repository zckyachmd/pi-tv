# Pi TV design system foundation

Proposed for owner review, 2026-11-27. This is a design contract, not production authorization or a validated UI. [PRD](../../PRD.md) and architecture govern behavior. The [reference pack](../../handoff/pitv-design-reference-pack/README.md) is illustrative and historical; [design-tokens.json](design-tokens.json) is the sole active token authority, version 1.1.0-proposed. The earlier handoff seed remains unchanged evidence. Changes to token meaning or removing roles require a major version; additions a minor version; corrections a patch, all subject to review.

Use solid dark surfaces, crisp outlines, clear labels and restrained blue emphasis. The TV defaults dark; iOS follows system appearance. Group content by task, keep feedback stable and legible, and avoid visual effects that compete with focus. Generic symbols and text are initial assets; board provider labels do not imply support. The boards' larger headings and exact dimensions are illustrative: use the token type scale, adaptive layout and native iOS controls instead. No copied product appearance, glow, halo, gradients, blur, hero art, autoplay or decorative animation.

## References reviewed 2026-11-27

| Official reference | Adopt | Reject |
|---|---|---|
| [Android TV layouts](https://developer.android.com/design/ui/tv/guides/styles/layouts) | Directional axes and 5% overscan protection | Treating Android dp as CSS pixels |
| [Android TV focus](https://developer.android.com/design/ui/tv/guides/styles/focus-system) | One clear focus and distinct pressed state | Scaling and glow as required focus effects |
| [Apple HIG accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Native accessibility, system behavior and user settings | Fixed phone layout copied from board; the web page required JavaScript, so its complete text was not verified in this session |
| [shadcn theming](https://ui.shadcn.com/docs/theming) | Semantic roles and foreground/background pairs | Installing a component library solely for styling |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) | Applicable AA text, non-text, focus and keyboard criteria | Claiming conformance from palette checks alone |

## Token contract

`primitives.color` holds hex values; `semanticColor.<appearance>` maps each role to a primitive key. Components use roles, never primitive names or literal colors. Status colors are foregrounds on background or surface, accompanied by text or icon. Disabled controls use disabled foreground/surface, never opacity alone; inactive-control WCAG exemptions do not remove the need for legibility. Interactive foreground is used on interactive fill; pressed foreground is used on pressed fill; focus is an outline against its adjacent surface. The dark border on raised surface is 2.68:1 and is decorative only; use focus or another verified boundary for meaningful controls there. See the validator for approved combinations; any new combination needs a contrast test.

Deterministic future mapping (specification only, no generator): for a CSS identifier split each path segment at a lowercase-or-digit to uppercase boundary, lowercase it, and join segments with hyphens. Emit semantic colors as `--color-<role>` within each appearance and resolve references to hex. Emit spacing and radius as CSS `px`; TV `*Px` as `px`, `safeMarginPercent` as `%`, reference dimensions as unitless pixel counts, motion as `ms`, and iOS `minimumHitTargetPt` as a unitless point count (not CSS pixels). Boolean and font values are not numeric CSS dimensions. For Swift use nested enums for JSON path segments; retain case, prefix identifiers beginning with a digit with `_`, and escape Swift keywords with backticks. Primitive keys are normalized by the same rule. Reject any collision after normalization within each output scope, including semantic color names and paths; never overwrite. Reject unsupported identifier characters instead of silently rewriting them. Platform point conversion is explicit at the use site, not assumed from CSS pixels. Compare any future generated output to JSON in CI; generated outputs are not independent authorities. iOS system accessibility overrides remain platform behavior.

Read [TV interaction](TV_INTERACTION.md), [iOS interaction](IOS_INTERACTION.md), [components](COMPONENT_CATALOG.md), [states](UI_STATE_MODEL.md), [accessibility](ACCESSIBILITY.md) and [quality gates](QUALITY_GATES.md). The application and session own state and authorization; presentation never owns credentials or security policy.
