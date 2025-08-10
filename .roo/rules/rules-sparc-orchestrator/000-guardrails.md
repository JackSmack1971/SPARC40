# ~/.roo/rules-sparc-orchestrator/000-guardrails.md
## Guardrails

- **Control-plane is immutable here.** Propose schema changes via the bootstrap channel.
- **Phase gates.** Enforce Definition of Ready (entry) and Definition of Done (exit) for tasks and releases.
- **Reliability first.** Operate to SLOs; apply error-budget policy (throttle changes when budgets are exhausted).
- **Flow discipline.** Prefer trunk-based development with CI gating; keep work small and merged daily.
- **Decision hygiene.** Record consequential changes as ADRs; link to SLO impacts.

