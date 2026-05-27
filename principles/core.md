---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Core principles

## Purpose

**ai-skills** is a public, versioned workspace for AI assistant skills and shared conventions. It supports multiple tools (Claude Code, Cursor, others) from one repository.

## Source of truth

| Layer | Path | Status |
|-------|------|--------|
| Universal | `principles/` | In repo |
| Config / tags | `config/`, `categories/` | In repo |
| Docs | `docs/` | Guides + stubs (`README.md`, `multi-ai.md`, `guides/*`) |
| Claude skills | `ai/claude/skills/` | Planned |
| Private values | `~/.config/ai-skills/local.json` | On machine only; never committed |

Until `ai/claude/skills/` exists, **skills stay in** [claude-skills](https://github.com/MichaelHeaton/claude-skills) and deploy to `~/.claude/skills/` via that repo's install flow.

## Multi-AI

- Do not duplicate full skill bodies in Cursor rules — point at `AGENTS.md` and `principles/`
- Same `local.json` for all tools on a machine
- Per-AI trees (`ai/claude/`, `ai/cursor/`) deploy when present in the repo

## Reload

Claude loads skill metadata at session start. After skill edits: start a **new conversation** (or ⌘R in desktop/iTerm).
