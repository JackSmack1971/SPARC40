# ~/.roo/rules-sparc-autonomous-orchestrator/README.md
# SPARC Autonomous Orchestrator — Rules (Global)

**Purpose**
Execute initial (or major re-) bootstrap: scaffold structure, generate/validate control-plane, seed rules/memory, and hand off to day-2.

**Scope**
- Project scaffolding
- Control-plane generation (`project/**/control/*.json`)
- Validation pipelines & reports

**Non-Goals**
- Routine ops and change management (day-2)
