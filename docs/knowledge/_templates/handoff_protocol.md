# Research → Implementation Handoff Protocol

**Purpose:** Ensure predictable, deterministic handoff from global research modes to project implementation orchestrator.

## Standard Output Paths (writeable by research team)
- `docs/knowledge/requirements.md`
- `docs/knowledge/architecture.md`
- `docs/knowledge/risk-register.md`
- `docs/knowledge/research-log.md`
- `docs/knowledge/BRIEF.md`
- `docs/knowledge/brief.json` (machine-readable File Map + Handoff)

## Handoff Token
- Generate a token: `HANDOFF-{YYYYMMDD}-{project_slug}-{rand6}`
- Include it in both `BRIEF.md` and `brief.json`.

## Validation
- Compute sha256 for each created file and record in `brief.json`.
- Impl orchestrator verifies presence + hash before first commit.

## Invocation
- Open impl orchestrator mode with the command: 
  - “Load `docs/knowledge/brief.json`, verify artifacts, and begin implementation planning.”
