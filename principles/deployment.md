---
version: 1.0.2
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Deployment principles

## Contexts

| Context | Mechanism | Status |
| --------- | ----------- | -------- |
| **System** | `make install-system` → `~/.claude/`, `~/.cursor/rules/` | **Present** |
| **Sync back** | `make sync-from-system` → repo | **Present** (dry-run default) |
| **Repo** | `make install-repo` → project `.cursor/rules` | Planned |
| **Manifest** | `.deploy/repo-manifest.json` | Present — `make manifest-update` |
| **Web UI** | Pasted instructions; no filesystem `local.json` | To be documented |

## Copy only — no symlinks

The git repo is source of truth. `~/.claude/` holds **copies**, never symlinks.

1. **Preferred:** Edit in repo → `make install-system`
2. **Alternative:** Edit under `~/.claude/` → `make sync-from-system` (dry-run, then `--apply`) → review → PR

## install-system

Deploys from `ai/claude/` and `ai/cursor/rules/`:

- `skills/` → `~/.claude/skills/`
- `hooks/*.py` → `~/.claude/hooks/`
- `CLAUDE.md` → `~/.claude/CLAUDE.md` (formatting overlay)
- `ai/cursor/rules/*.mdc` → `~/.cursor/rules/` (copy only; does not remove other rules you add locally)
- `memory/` → `~/.claude/projects/<encoded-repo-path>/memory` (copy)
- `log-clip` → `~/.local/bin/clog`
- `config/local.template.json` → `~/.config/ai-skills/local.json` (create-if-missing only)

Removes retired skills (`uv-weekly`, `pr-slack`) and retired Cursor rules (see `RETIRED_CURSOR_RULES` in `scripts/lib/deploy-paths.sh`) from the system install.

**Does not overwrite:** `settings.json`, `CLAUDE.local.md`, filled `local.json`.

**Safety:** Aborts if a system skill looks newer than repo (unsynced edits). Use `make sync-from-system` first, or `make install-system --force`.

## Repo lint hooks

Markdown and YAML lint run via **pre-commit** (`.pre-commit-config.yaml`). On playbook-managed Macs, **workstation-devops** runs `make hooks-install` after `make install-system` on every clone and `make apply`. Manual: `brew install pre-commit && make hooks-install`. Check anytime: `make lint`. CI: `.github/workflows/lint.yml`.

## sync-from-system

Whitelist only — never pulls secrets or private config.

| System | Repo |
| -------- | ------ |
| `~/.claude/skills/<name>/` | `ai/claude/skills/<name>/` |
| `~/.claude/hooks/*.py` | `ai/claude/hooks/` |
| `~/.claude/CLAUDE.md` | `ai/claude/CLAUDE.md` |
| `~/.claude/projects/.../memory/` | `ai/claude/memory/` |
| `~/.cursor/rules/*.mdc` (repo-managed files only) | `ai/cursor/rules/` |

After `--apply`: bump `version` on edited files, `make manifest-update`, open PR via `git-ops`.

## One-time migration from symlink installs

`make unlink-legacy` materializes `~/.claude/skills` as copies and can migrate config to `~/.config/ai-skills/`. Run once when moving off claude-skills symlink installs, then use `make install-system` from this repo.
