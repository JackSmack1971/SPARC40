# ~/.roo/rules-research-orchestrator/000-guardrails.md
## Guardrails

- **No control-plane edits.** Produce specifications; do not modify `project/**/control/*.json`.
- **Evidence over opinion.** Prefer primary specs/standards. Annotate claims with sources and confidence.
- **Decision hygiene.** Capture significant choices as ADRs; link assumptions/risks.
- **Risk framing.** Use a lightweight register (impact, likelihood, owner, mitigation).
- **Readiness gates.** Maintain a **Definition of Ready** (optional) for items entering bootstrap; hold a **Definition of Done** for completed research artifacts.
- **Compliance & safety.** Identify applicable regs/standards early; flag AI risks and evaluation needs for downstream teams.
