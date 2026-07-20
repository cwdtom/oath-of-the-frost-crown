## Agent skills

### Issue tracker

Issues and PRDs are tracked in this repository's GitHub Issues; external pull requests are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository with one root `CONTEXT.md` and root-level ADRs under `docs/adr/`. See `docs/agents/domain.md`.

### Godot tests

Run Godot tests sequentially. Do not run two or more Godot test processes in parallel.
