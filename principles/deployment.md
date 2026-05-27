---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Deployment principles

## Contexts

| Context | Mechanism | Status |
|---------|-----------|--------|
| **System** | `make install-system` → `~/.claude/` | Planned |
| **Repo** | `make install-repo` → project `.cursor/rules` | Planned |
| **Web UI** | Pasted instructions; no filesystem `local.json` | To be documented |

## Copy only — no symlinks

The git repo is source of truth. `~/.claude/` holds **copies**, never symlinks.

1. **Preferred:** Edit in repo, then install
2. **Alternative:** Edit under `~/.claude/`, then `make sync-from-system` before commit (when available)

## One-time migration from symlink installs

`make unlink-legacy` (when added under `scripts/`) materializes `~/.claude/skills` as copies and can migrate config to `~/.config/ai-skills/`. Safe to run once when moving off symlink-based claude-skills installs.

## Before skills live here

Skills are developed in **claude-skills** and copied to `~/.claude/skills/` via that repo. This repository does not contain `ai/claude/` until import is complete.
