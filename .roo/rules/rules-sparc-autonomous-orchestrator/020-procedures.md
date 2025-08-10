# ~/.roo/rules-sparc-autonomous-orchestrator/020-procedures.md
## Procedures

1) **Scaffold**
   - Create baseline folders, `.roo/rules-*`, memory seeds, and CI stubs.
   - Add pre-commit hooks for formatting, linting, and schema checks.

2) **Generate Control-Plane**
   - Materialize `project/**/control/*.json` from approved research inputs.
   - Embed `$schema` URIs; version schemas alongside code.

3) **Validate**
   - Local validation: structural + semantic checks.
   - CI validation: repeat with **fail-fast** gates; upload artifacts (diffs, logs).

4) **Security & CI Hardening**
   - Pin build actions; restrict permissions; scoped secrets.
   - Add dependency review and artifact integrity checks where supported.

5) **Report & Transfer**
   - Publish `docs/BOOTSTRAP_REPORT.md` with what changed, why, and how to roll back.
   - Handoff to day-2 orchestrator with ownership map and next-phase checklist.
