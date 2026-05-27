---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Core principles

## Purpose

**ai-skills** is a public, versioned workspace for AI assistant skills and shared conventions. It supports multiple tools (Claude Code, Cursor, others) from one repo.

## Source of truth

| Layer | Path | Role |
|-------|------|------|
| Universal | `principles/` | Rules all AIs follow |
| Claude | `ai/claude/skills/` | Claude Code skills |
| Cursor | `ai/cursor/rules/` | Cursor rules (PR 4+) |
| Private values | `~/.config/ai-skills/local.json` | Never committed |

## Repo layout

- Edit skills in **`ai/claude/skills/<name>/SKILL.md`**
- Deploy with **`make install-system`** (copy to `~/.claude/`, never symlinks)
- Pull session edits back with **`make sync-from-system`** before committing

## Multi-AI

- Do not duplicate full skill bodies in Cursor rules — point at `AGENTS.md` and `principles/`
- Same `local.json` for all tools on a machine
- See [docs/multi-ai.md](../docs/multi-ai.md) (updated each PR until stable)

## Reload

Claude loads skill metadata at session start. After skill edits: **new conversation** (or ⌘R in desktop/iTerm).
