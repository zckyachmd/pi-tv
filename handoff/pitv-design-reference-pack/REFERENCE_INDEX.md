# Reference index — curated official sources

Reviewed/search-checked 2026-11-27. Use for principles, not source assets. External visual examples are links only, not redistributed images. Recheck exact guidance if making a new normative claim; do not restart broad inspiration research.

| Source | Apply | Avoid |
|---|---|---|
| [Android TV — Design for TV](https://developer.android.com/design/ui/tv/guides/foundations/design-for-tv) | distance legibility, explicit remote feedback | copying Android branding |
| [Android TV — Layouts](https://developer.android.com/design/ui/tv/guides/styles/layouts) | directional axes, spacing, safe layout | assuming Android dp equals Pi CSS px |
| [Android TV — Focus system](https://developer.android.com/design/ui/tv/guides/styles/focus-system) | distinct default/focused/pressed states | glow, heavy scaling, decorative effects |
| [Android TV — Cards](https://developer.android.com/design/ui/tv/guides/components/cards) | card anatomy and hierarchy | copying poster assets or content-feed design |
| [Apple HIG — Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles) | predictable native feedback and choices | pixel-copy of Apple TV remote |
| [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | VoiceOver, Dynamic Type, contrast and accessible controls | assuming static visual audit proves accessibility |
| [Apple HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) | appearance-aware roles and semantic colors | fixed custom style overriding system needs |
| [shadcn/ui — Theming](https://ui.shadcn.com/docs/theming) | semantic background/foreground pairs and component variants | mandatory library installation or Tailwind adoption |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) | applicable web contrast, keyboard/focus requirements | claiming compliance solely from token tests |

## Direct visual references (external, inspect only)

- [Android TV layout/navigation illustration](https://developer.android.com/design/ui/tv/guides/styles/images/layouts/optimize-with-axes.webp) — directional axes. Source: Android TV Layouts.
- [Android TV focused element anatomy](https://developer.android.com/design/ui/tv/guides/styles/images/focus-system/focus-anatomy.webp) — focus vs focusable surface. Source: Android TV Focus system.
- [Android TV card states](https://developer.android.com/static/design/ui/tv/guides/components/images/cards/wide-standard-card-states.webp) — card variants, not assets for Pi TV. Source: Android TV Cards.
- [Apple HIG Dark Mode examples](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — inspect page illustrations, adopt native semantic behavior.
- [shadcn/ui theming examples](https://ui.shadcn.com/docs/theming) — inspect semantic roles, not a mandate to add dependencies.

The bundled `visuals/` are original schematic references created for this project using the earlier candidate token seed and generic geometric shapes. No third-party screenshot is needed to complete Session 1C.2. If external links are unavailable, record the limitation and continue using the bundled references and known requirements.
