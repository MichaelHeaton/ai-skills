---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Claude Code deployment

## Layout

| Path | Deploy target |
|------|----------------|
| `skills/` | `~/.claude/skills/` |
| `hooks/*.py` | `~/.claude/hooks/` |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` (formatting; skip if user-owned — PR 2) |
| `memory/` | `~/.claude/projects/<encoded-repo-path>/memory` |

## Config

Read order for placeholders:

1. `config/local.json` in repo checkout (gitignored, optional)
2. `~/.config/ai-skills/local.json`

## Commands

| Command | Status |
|---------|--------|
| `make install-system` | PR 2 |
| `make sync-from-system` | PR 2 |
| `make unlink-legacy` | Available (Phase 0) |

## Reload

New conversation after `SKILL.md` changes.
