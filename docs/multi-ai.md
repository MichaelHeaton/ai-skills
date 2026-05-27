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
| **Claude deploy** | `ai/claude/` (present) | Copied to `~/.claude/` via `make install-system` |
| **Cursor overlay** | `ai/cursor/rules/` (planned) | Cursor |
| **Private config** | `~/.config/ai-skills/local.json` | All agents on your machine |

## Claude Code

Skill bodies: **`ai/claude/skills/`** in this repo.

```bash
cd ~/Projects/personal/ai-skills
make install-system    # copy-only deploy repo → ~/.claude/
make sync-from-system  # dry-run: pull allowed ~/.claude/ edits back into repo
```

- Skills: `~/.claude/skills/<name>/` (copies, never symlinks)
- Reload: new conversation (or ⌘R in desktop/iTerm)
- Machine-specific: `~/.claude/CLAUDE.local.md` (never committed)

See [principles/deployment.md](../principles/deployment.md).

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

On the maintainer’s Macs, **[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops)** (`make apply`) clones **ai-skills**, **claude-skills**, and **[Memex](https://github.com/MichaelHeaton/memex)** and runs **`make install-system`** in ai-skills. It does **not** store filled `local.json` (templates only).
