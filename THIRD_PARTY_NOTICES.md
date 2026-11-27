# Third-party notices

This is an inventory of identifiable material, not a complete notice bundle or SBOM. Third-party components retain their own terms. Version-specific license texts, copyrights and attribution must be checked and included as applicable before distribution; a lockfile alone does not establish license compatibility.

- The root [GPL text](LICENSE) and [handoff copy](handoff/pitv-planning-handoff/LICENSE) contain the Free Software Foundation's copyright notice and permission to copy and distribute the license document verbatim. Its terms apply only to works actually licensed under it; see [scope](LICENSING.md).
- The historical [Rust daemon prototype](prototypes/host-first/daemon/Cargo.toml) directly uses Axum, libc, Serde, serde_json, Tokio, tracing and tracing-subscriber, plus futures-util and tokio-tungstenite for development. Exact resolved versions and 91 total package records are in its [lockfile](prototypes/host-first/daemon/Cargo.lock). Their individual licenses, notices and transitive compatibility remain to be verified; no third-party source is identified as vendored by these manifests.
- The [wireframe generator](handoff/pitv-wireframe-handoff/scripts/generate.py) imports Pillow and CairoSVG and references DejaVu Sans, with a fontconfig fallback. Versions, actual generation environment, rights and attribution requirements are unverified. Generated output remains subject to provenance review.
- The [package feasibility script](scripts/phase0b/package-feasibility.sh) names Chromium, Cage, labwc, PipeWire, font and native system packages for simulations. This does not establish what would ship, their exact versions or licenses. Review each selected package, codec and dependency before distribution.
- Apple SDK frameworks are used by the historical [iOS prototype](prototypes/host-first/ios-swift/Package.swift); applicable SDK and distribution terms require review. The package declares no external Swift package dependencies.

The root license was compared byte-for-byte with the [canonical GNU text](https://www.gnu.org/licenses/gpl-3.0.txt) on 2026-11-27; see the inventory for the digest.

See the [provenance inventory](docs/planning/session-1c4-provenance.md) for evidence, unknowns and distribution status. No release is cleared by this file.
