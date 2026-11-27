# Repository instructions

- Treat the PRD, active architecture and design documents as current requirements and proposals; consult their status and traceability. Handoffs and prototypes are historical where superseded.
- Follow [module boundaries](docs/architecture/MODULE_BOUNDARIES.md); adapters do not grant authority, and prototypes are not production dependencies.
- Use canonical design tokens and component contracts; follow [quality gates](docs/design/QUALITY_GATES.md) and [active v2 wireframes](docs/design/wireframes/v2/README.md). Do not regenerate or edit historical handoffs.
- Preserve keyboard-free customer operation on prepared media and the Pi 4B 1 GB constraint. Do not disrupt existing host workloads.
- Pairing and authorization require independent security review. Do not implement production software without explicit owner approval.
- Review dependencies, licenses, footprint and maintenance before admission; follow the [engineering policy](docs/engineering/ENGINEERING_POLICY.md).
- Report actual evidence, failures and skipped checks without implying untested capabilities. Persist completed deliverables progressively and record checkpoints.
- Do not access or mutate hardware without explicit authorization; never expose secrets in code, logs or evidence.
