# Accessibility and localization

PRD R-19 applies to both platforms. TV web targets WCAG 2.2 AA as applicable: normal text ≥4.5:1, large text ≥3:1, applicable control boundaries and focus ≥3:1 against adjacent colors; focus is visible and not obscured. Aim for the WCAG 2.4.13 focus appearance area and change-of-contrast criteria as an additional AAA goal, not an AA claim. Status has text or icon as well as color. Contrast checks cover declared combinations, not screenshots, alpha, anti-aliasing or every possible placement.

All TV actions must work with keyboard only, with a visible logical focus and no keyboard trap except a dismissible modal. Native iOS preserves VoiceOver, Dynamic Type, system contrast, Reduce Motion, safe areas and 44 pt targets; test actual assistive technologies, not only accessibility identifiers. Announce meaningful changes without excessive interruption. Motion must not be required for comprehension.

Externalize all visible strings, accessibility names and hints; support expansion, pluralization, locale formatting and right-to-left layouts without encoding direction in icons or focus logic. Never truncate critical error or security instructions. Verify long pseudolocalized strings and RTL focus geometry. Runtime assistive technology, real TV distance and localization testing remain release gates.
