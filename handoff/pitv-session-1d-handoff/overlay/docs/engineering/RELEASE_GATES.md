# Release and publication gates

Proposed checklist, not legal advice, license adoption or authorization to distribute. Based on [licensing scope](../../LICENSING.md), [distribution compliance](DISTRIBUTION_COMPLIANCE.md), [provenance inventory](../planning/session-1c4-provenance.md) and [governance checkpoint](../planning/session-1c4-completion.md). Gates apply to the actual material, recipient and channel, not just release binaries.

| Gate | Required evidence | Status |
|---|---|---|
| G-PUB | Repository was public at review; identify currently exposed code/assets/docs with unresolved rights; owner reviews visibility and remediation, do not change visibility automatically | Open, owner action now |
| G-LIC | GPL-3.0-only for first-party Rust core and TV launcher only; establish actual contribution rights and file scope; iOS, visual assets, docs, scripts, schemas and generated outputs unresolved | Partial, owner/legal review |
| G-DEPS | Version-specific admitted direct/transitive/native dependency licenses, provenance, maintenance, advisories, compatible terms and attribution; SBOM for actual build/image | Open |
| G-TRADE | Working name and official identity, actual mark rights and third-party policies; no restriction on GPL rights or mandatory upstream contribution | Open |
| G-SEC | Independent secure channel/enrollment/recovery and browser isolation review, negative tests, threat residuals, verified private reporting channel | Open |
| G-HW | Actual Pi 4B 1 GB, physical iPhone, no-HID flow, compatibility matrix, measured performance and shared-host protection if claimed | Open |
| G-QA | Contract, accessibility, 30 switches, 24h integrated soak, proposed 72h release reliability and regression evidence | Open |
| G-LINUX | Actual Debian package and prepared media bill of materials, signed scoped-keyring APT metadata, install/upgrade/rollback, per-component redistribution rights; no cloned keys | Open |
| G-SOURCE | GPL corresponding source under applicable section 6 option; installation information if applicable, actual delivery and retention; preserve notices | Open |
| G-MEDIA | Provider and browser/codec/CDM/firmware permissions and lawful use; no DRM bypass or unlicensed proprietary bundling | Open |
| G-IOS | Selected iOS license, rights and actual Apple channel-specific compliance; signing and distribution review | Blocked |
| G-OWNER | Explicit approval per artifact/channel, known limitations, support/security policies, reproducible evidence | Open |

## Internal experimentation vs publication

Owner-authorized private local experimentation with lawfully obtained materials, SDK and test-device rights may proceed without closing every release gate. Confirm actual signing terms and recipients: distributing development builds to others, TestFlight, App Store and public source publication are distinct from compiling/testing on one's own device. Do not assume internal use or public repo automatically clears rights. Do not publish new unresolved material or share binaries without owner and appropriate compliance approval. No iOS distribution until scope and applicable terms are approved. Existing public exposure is not undone by changing visibility; owner must assess. Do not force GPL across unresolved material or add an exception unilaterally.
