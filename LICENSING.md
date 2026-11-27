# Licensing scope

The product owner selected **GPL-3.0-only** for the first-party Rust core and TV launcher. [LICENSE](LICENSE) contains GPL version 3. This decision does not authorize relicensing material whose rights are held by others or whose provenance is unresolved.

| Material | Scope and status |
| --- | --- |
| First-party Rust core and TV launcher | Owner-selected GPL-3.0-only, subject to identifying first-party material and confirming contribution rights. |
| iOS remote | License deferred; distribution blocked pending licensing and platform compliance review. |
| Design assets and visual artifacts | Provenance and license undetermined. |
| Documentation, build and packaging scripts, shared schemas and generated artifacts | Scope requires explicit determination. |
| Third-party components | Original applicable licenses remain in force. |
| Historical prototypes and handoffs | File-level provenance and scope require audit; do not assume the core decision covers them. |

The [provenance inventory](docs/planning/session-1c4-provenance.md) records the initial audit and canonical GNU text comparison. Full contribution and dependency rights verification, corresponding-source preparation, and iOS and trademark review remain release gates; see [distribution compliance](docs/engineering/DISTRIBUTION_COMPLIANCE.md). No SPDX headers have been added pending that audit. GPL permits commercial redistribution and does not require sending changes upstream. The separate [trademark policy](TRADEMARK_POLICY.md) does not change copyright licenses.
