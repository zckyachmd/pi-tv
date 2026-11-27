# Pi TV design system foundation

Proposed for owner review, 2026-11-27. This is a design contract, not production authorization or a validated UI. [PRD](../../PRD.md) and architecture govern behavior. The [reference pack](../../handoff/pitv-design-reference-pack/README.md) is illustrative and historical; [design-tokens.json](design-tokens.json) is the sole active token authority, version 1.0.0-proposed. The earlier handoff seed remains unchanged evidence. Changes to token meaning or removing roles require a major version; additions a minor version; corrections a patch, all subject to review.

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

`primitives.color` holds hex values; `semanticColor.<appearance>` maps each role to a primitive key. Components use roles, never primitive names or literal colors. Status colors are foregrounds on background or surface, accompanied by text or icon. Disabled controls use disabled foreground/surface, never opacity alone; inactive-control WCAG exemptions do not remove the need for legibility. Interactive foreground is used on interactive fill; focus is an outline against its adjacent surface. The dark border on raised surface is 2.68:1 and is decorative only; use focus or another verified boundary for meaningful controls there. See the validator for approved combinations; any new combination needs a contrast test.

Deterministic future mapping: convert camelCase role names to kebab-case and emit `--color-<role>` for each appearance, resolved to the primitive hex; emit other numeric leaves as `--<path-in-kebab-case>` with `px` for TV dimensions, `ms` for motion, `%` for safe margin and unitless values otherwise. Swift constants use the same JSON paths as nested enums with original camelCase keys, colors resolved to RGB and dimensions in points where explicitly marked. iOS uses system fonts, Dynamic Type and native semantic colors when accessibility settings require them; such overrides are platform behavior, not an alternate token source. Build-time generation or a small checked mapping is allowed; generated outputs must be compared to JSON in CI, never edited as independent authorities. No generator is mandated before implementation.

Read [TV interaction](TV_INTERACTION.md), [iOS interaction](IOS_INTERACTION.md), [components](COMPONENT_CATALOG.md), [states](UI_STATE_MODEL.md), [accessibility](ACCESSIBILITY.md) and [quality gates](QUALITY_GATES.md). The application and session own state and authorization; presentation never owns credentials or security policy.
