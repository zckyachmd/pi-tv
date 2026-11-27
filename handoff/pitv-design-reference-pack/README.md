# Pi TV — Session 1C.2 design reference pack

Status: supplemental **proposed** design reference, not an approved mockup, production code, hardware evidence, or a new source of truth. Prepared 27 November 2026 for the Session 1C.2 baseline `c3dd5b726a970002fb8d2147865dba8e42a583d3`. Recheck repository HEAD before work.

## Place in repository

Extract the directory into `handoff/pitv-design-reference-pack/`. Keep the earlier `handoff/pitv-planning-handoff/` intact. Do not install packages or create UI components to use these references.

Read in order:

1. `DESIGN_BRIEF.md` — decisions, reference interpretation, constraints.
2. `REFERENCE_INDEX.md` — official external visual and technical references.
3. `visuals/01-tv-launcher.png`, `visuals/02-ios-remote.png`, `visuals/03-component-states.png` — original illustrative reference boards. SVG equivalents are supplied for exact geometry and color inspection. PNG is preferred for vision-capable agents; SVG source is the fallback.
4. `CODEX_ADDENDUM.md` — append to the existing Session 1C.2 prompt.

The existing PRD, architecture, recovery, benchmark and BLE documents remain authoritative for product behavior. The seed `handoff/pitv-planning-handoff/design-tokens.json` remains the input; Session 1C.2 should produce the canonical active token file, not treat the illustrative SVG values as a second token authority.

The illustrations use original generic geometric icons and text; no vendor logos, fonts, screenshots or marketing images are bundled. The images show hypothetical states and named reference providers, not verified support. Do not ship the boards as UI assets. Rights/provenance for production assets and product marks remain review gates. No official endorsement is implied.
