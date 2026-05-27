---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Token efficiency

Token cost is a first-class design constraint.

## Skills and rules

- One topic per file; no monolithic catch-alls
- Put rarely needed detail in `skills/<name>/references/` and link from `SKILL.md`
- Keep descriptions trigger-focused but under 1024 characters (Claude truncates silently)

## Logs and command output

- Filter before pasting large logs into a session (`grep`, `awk`, or `scripts/filter-log.sh` when added)
- Prefer dedicated parsers for repeated log types (PR 6+)

## Scripts over prose

- Repeatable steps belong in `scripts/` with a one-line skill invocation
- Do not duplicate `principles/` text inside skills — link instead

## Deploy manifests

Use `.deploy/repo-manifest.json` and `make manifest-update` to diff only changed deploy paths instead of re-reading entire trees.
