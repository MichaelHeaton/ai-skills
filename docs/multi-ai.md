# Multi-AI setup (Claude Code + Cursor)

One repo, multiple tools — each reads what it understands natively.

## Source of truth

| Layer | Path | Who reads it |
|-------|------|----------------|
| **Universal** | [principles/](../principles/) + [AGENTS.md](../AGENTS.md) | All agents |
| **Claude overlay** | [CLAUDE.md](../CLAUDE.md) | Claude Code |
| **Claude deploy** | [ai/claude/](../ai/claude/) | Copied to `~/.claude/` via `make install-system` (PR 2) |
| **Cursor overlay** | `ai/cursor/rules/` (PR 4) | Cursor |
| **Private config** | `~/.config/ai-skills/local.json` | All agents on your machine |

## Claude Code

```bash
make install-system   # PR 2 — copy-only deploy
make sync-from-system  # PR 2 — pull ~/.claude edits into repo
```

- Skills: `ai/claude/skills/` → `~/.claude/skills/`
- Reload: new conversation (or ⌘R in desktop/iTerm)
- No symlinks — see [principles/deployment.md](../principles/deployment.md)

## Cursor

1. Open **ai-skills** in your workspace (or parent workspace that includes it).
2. PR 4 adds `ai/cursor/rules/` — thin rules pointing at `AGENTS.md`.
3. Full `install-repo` deploy — PR 7.

## What not to do

- Do not duplicate full skill bodies in Cursor rules.
- Do not commit employer URLs or names — use [categories/tags.yaml](../categories/tags.yaml) placeholders.

## Legacy

Content imported from [claude-skills](https://github.com/MichaelHeaton/claude-skills). Phase 0: `make unlink-legacy`.
