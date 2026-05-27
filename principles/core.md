---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Core principles

## Purpose

**ai-skills** is a public, versioned workspace for AI assistant skills and shared conventions. It supports multiple tools (Claude Code, Cursor, others) from one repository.

## Source of truth (phased rollout)

| Layer | Path | When |
|-------|------|------|
| Universal | `principles/` | Now (PR-A) |
| Config / tags | `config/`, `categories/` | PR-B |
| Docs | `docs/` | PR-C |
| Claude skills | `ai/claude/skills/` | PR-F (not yet) |
| Private values | `~/.config/ai-skills/local.json` | Never committed |

Until PR-F lands, **skills stay in** [claude-skills](https://github.com/MichaelHeaton/claude-skills) and deploy to `~/.claude/skills/` via that repo's install flow.

## Multi-AI

- Do not duplicate full skill bodies in Cursor rules — point at `AGENTS.md` and `principles/`
- Same `local.json` for all tools on a machine (PR-B documents schema)
- Per-AI deploy trees (`ai/claude/`, `ai/cursor/`) come in later PRs

## Reload

Claude loads skill metadata at session start. After skill edits: start a **new conversation** (or ⌘R in desktop/iTerm).
