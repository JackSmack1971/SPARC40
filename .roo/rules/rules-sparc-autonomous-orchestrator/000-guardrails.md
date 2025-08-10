# ~/.roo/rules-sparc-autonomous-orchestrator/000-guardrails.md
## Guardrails

- **Schema-first.** Every control-plane file declares a `$schema` and passes **JSON Schema 2020-12** validation locally and in CI.
- **Change safety.** Small PRs; descriptive commits; reversible steps; no force-push.
- **Supply-chain hygiene.** Pin actions/deps by version or digest; use least-privilege tokens/secrets in CI.
- **Dry-run then apply.** For generators and infra scripts, run idempotent dry-runs before writes.
- **Report & rollback.** Produce a bootstrap report with diffs, validation results, and rollback notes.
