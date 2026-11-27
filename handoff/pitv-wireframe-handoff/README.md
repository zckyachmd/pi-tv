# Pi TV wireframe handoff — v2 proposal

Replacement design-only artifacts for Session 1C.3B and 1C.3C. Reviewed repository baseline `8989129221a08035b226b95f431238b7db8540f6`. The supplied assets are original static SVG/PNG concepts, not working UI, certified providers, real screenshots of iOS, or ratified security flows. The visual language retains repository token version `1.1.0-proposed`; `token-snapshot.json` is a reproduction input, NOT a second active design-token authority. Compare it against `docs/design/design-tokens.json` before integration.

- [Keyboard-free requirements](KEYBOARD_FREE_REQUIREMENTS.md): owner direction and proposed onboarding/recovery model, with limitations and feasibility gates.
- [Codex prompt](CODEX_PROMPT.md): integration and specification reconciliation only.
- [TV index](wireframes/tv/README.md): 10 base screen groups at 1920×1080 and 1280×720, and 8 selected variants at both sizes.
- [iOS index](wireframes/ios/README.md): 10 base screen groups at 390×844 in light/dark, 6 selected variants in both appearances, and 2 compact D-pad previews.
- `manifest.json`: exact artifact names, dimensions and state tags. 70 SVG/PNG pairs (36 TV, 34 iOS).
- `*-overview.png`: contact sheets for review; individual source files remain the precise references.
- `scripts/generate.py`: design-only reproducibility tool. Run `python3 scripts/generate.py --tokens /path/to/repository/docs/design/design-tokens.json` from a development host with Python, Pillow, CairoSVG and DejaVu Sans/fontconfig. System font is a static preview substitute, not a required iOS or TV production font; font files are not included. CairoSVG/Pillow are not runtime dependencies.

## Scope of validation

Generation checks SVG XML parsing, PNG dimensions, canvas rectangles and approximate text widths using Pillow/font metrics, with fixed semantic colors from the snapshot. Individual screens and representative contact sheets were visually inspected. Not an exhaustive per-element overlap, all localized labels/RTL, Dynamic Type, native hit-testing, real TV distance, accessibility, screen reader, focus-graph execution, performance, BLE, DRM, or physical-device test. All QR placeholders intentionally contain no enrollment data and are invalid. The sample phrase is illustrative only. No provider logos or real account information included. Generic vector symbols were authored for this pack. No product or legal claims.

The layout intentionally has no keyboard/mouse requirement for normal end-user use. The underlying security and recovery mechanisms still need the independent feasibility/review gates in the requirements file. A fatal hardware/OS fault or loss of all ownership proof may require maintenance/re-provisioning. Review owner scope before changing release policy.
