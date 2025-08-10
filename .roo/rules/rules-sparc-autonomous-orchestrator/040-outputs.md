# ~/.roo/rules-sparc-autonomous-orchestrator/040-outputs.md
## Outputs (Acceptance)

- `project/**/control/*.json` — validated against declared schemas.
- `.roo/rules-{slug}/` — initialized with numbered rules files.
- `docs/BOOTSTRAP_REPORT.md` — diffs, validations, decisions, rollback, owners.
- CI: required jobs for schema check, lint, unit tests.

**Quality Gates**
- All control-plane artifacts validate under 2020-12.
- CI jobs are green; actions pinned; least-privilege enforced.
- Handover doc identifies owners and day-2 readiness.
