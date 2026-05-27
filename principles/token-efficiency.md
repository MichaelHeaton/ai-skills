---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Token efficiency

Token cost is a first-class design constraint.

## Skills and rules

- One topic per file; avoid monolithic catch-alls
- Put rarely needed detail in per-skill `references/` and link from `SKILL.md`
- Keep Claude `description` under 1024 characters (silent truncation breaks triggering)

## Logs and command output

- Filter before pasting large logs (`grep`, `awk`, or dedicated scripts when available)
- Prefer parsers for log types you hit repeatedly

## Scripts over prose

- Repeatable steps belong in `scripts/` with a one-line skill invocation
- Link to `principles/` instead of copying rules into every skill

## Deploy manifests

MD5 manifests under `.deploy/` (when present) let install and sync scripts diff only changed paths — see [deployment.md](deployment.md).
