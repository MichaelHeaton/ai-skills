---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Multi-AI setup (Claude Code + Cursor)

One repo, multiple tools — each reads what it understands natively. Nothing forces Claude-only or Cursor-only patterns into the wrong product.

## Source of truth

| Layer | Path | Who reads it |
|-------|------|----------------|
| **Universal** | [principles/](../principles/) + [AGENTS.md](../AGENTS.md) | All agents |
| **Claude overlay** | [CLAUDE.md](../CLAUDE.md) | Claude Code |
| **Claude deploy** | `ai/claude/` (planned) | Copied to `~/.claude/` via `make install-system` |
| **Cursor overlay** | `ai/cursor/rules/` (planned) | Cursor |
| **Private config** | `~/.config/ai-skills/local.json` | All agents on your machine |

## Claude Code (today)

Until `ai/claude/skills/` exists in this repo, develop and deploy from [claude-skills](https://github.com/MichaelHeaton/claude-skills):

```bash
cd ~/Projects/personal/claude-skills && make install
```

- Skills: `~/.claude/skills/<name>/` from legacy repo `skills/<name>/`
- Reload: new conversation (or ⌘R in desktop/iTerm)
- Machine-specific: `~/.claude/CLAUDE.local.md` (never committed)

## Claude Code (target)

```bash
make install-system    # copy-only deploy repo → ~/.claude/
make sync-from-system  # pull allowed ~/.claude edits back into repo
```

See [principles/deployment.md](../principles/deployment.md) — no symlinks.

## Cursor

1. Open **ai-skills** in your workspace (or a parent workspace that includes it).
2. When `ai/cursor/rules/` lands, thin rules will point at `AGENTS.md` and `principles/`.
3. Start a **new chat** after skill or rule edits (no ⌘R in VS Code).
4. Read private config from `~/.config/ai-skills/local.json` when skills reference local values.

## What not to do

- Do not duplicate full skill bodies in Cursor rules — point at `AGENTS.md` or skill paths.
- Do not commit employer URLs, Jira keys, or coworker names — use [categories/tags.yaml](../categories/tags.yaml) placeholders and `~/.config/ai-skills/local.json`.
- Do not require Claude slash-command syntax in Cursor-only flows.

## Workstation bootstrap

[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops) will clone this repo and run install targets. It does **not** store your filled `local.json` (that file stays on the machine only).
