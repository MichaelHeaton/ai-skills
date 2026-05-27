---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Deployment principles

## Contexts

| Context | Mechanism | Status |
|---------|-----------|--------|
| **System** | `make install-system` → `~/.claude/` | PR-G |
| **Repo** | `make install-repo` → project `.cursor/rules` | PR-I |
| **Web UI** | Pasted instructions; no `local.json` on disk | Documented PR-H |

## Copy only — no symlinks

The git repo is source of truth. `~/.claude/` holds **copies**, never symlinks.

1. **Preferred:** Edit in repo, then install
2. **Alternative:** Edit under `~/.claude/`, then `make sync-from-system` before commit (PR-G)

## Phase 0 (done on author machine)

`make unlink-legacy` materialized `~/.claude/skills` copies and migrated config to `~/.config/ai-skills/`. Script lands in PR-D for others.

## Until PR-F

Skills are developed in **claude-skills** and copied to `~/.claude/skills/` via that repo. **ai-skills** does not contain `ai/claude/` until the dedicated import PR.
