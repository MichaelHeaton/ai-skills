---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Deployment principles

## Contexts

| Context | What deploys | Config |
|---------|--------------|--------|
| **System** | `make install-system` → `~/.claude/` | `~/.config/ai-skills/local.json` |
| **Repo** | `make install-repo` (PR 7) → project `.cursor/rules` | Same local.json |
| **Web UI** | No filesystem; paste minimal instructions | Documented in `docs/deployment-contexts.md` (PR 5) |

## Copy only — no symlinks

The repo is git source of truth. `~/.claude/` holds **copies**. Never deploy symlinks to skill trees.

1. **Preferred:** Edit in repo, then `make install-system`
2. **Alternative:** Edit under `~/.claude/`, then `make sync-from-system` (dry-run first)

## Install safety

- `install-system` compares MD5 manifests; aborts if system has unsynced changes (unless `--force`)
- **Sync-before-install** when you edited deployed copies

## Phase 0

Run `make unlink-legacy` once when migrating from legacy `claude-skills` symlink installs.

## Manifest files

| File | Purpose |
|------|---------|
| `.deploy/repo-manifest.json` | Committed hashes of deployable repo paths |
| `.deploy/system-manifest.json` | Gitignored; last install to `~/.claude` |
| `.deploy/last-sync.json` | Gitignored; last successful sync-back |
