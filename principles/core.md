---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-09-15
updated_by: claude
---

# Core principles

## Purpose

**ai-skills** is a public, versioned workspace for AI assistant skills and shared conventions. It supports multiple tools (Claude Code, Cursor, others) from one repository.

## Source of truth

| Layer | Path | Status |
| ------- | ------ | -------- |
| Universal | `principles/` | In repo |
| Config / tags | `config/`, `categories/` | In repo — placeholders only; values in `local.json` |
| Docs | `docs/` | Guides + stubs (`README.md`, `multi-ai.md`, `guides/*`) |
| Tooling | `scripts/`, `Makefile` | In repo |
| Claude skills | `ai/claude/skills/` | Present — deploy via `make install-system` |
| Private values | `~/.config/ai-skills/local.json` | On machine only; never committed |

## Multi-AI

- Do not duplicate full skill bodies in Cursor rules — point at `AGENTS.md` and `principles/`
- Same `local.json` for all tools on a machine
- Skills are **domain-aware** — see [domains.md](domains.md)
- Per-AI trees (`ai/claude/`, `ai/cursor/`) deploy when present in the repo

## Decision authority — when to ask vs. decide

Most ambiguity hit mid-plan is an implementation-shape question — standalone skill vs. a doc addition to an existing one, which existing pattern to follow, how to scope a fix — the kind of call a competent engineer makes from precedent and convention, not one that needs Michael specifically. Default to deciding it yourself: check `references/conventions.md`, a sibling skill's existing shape, or a prior logged decision (`Wiki/Concepts/*-Decision.md`) for precedent, state the decision and its rationale inline (in the plan, the ticket, or the PR description), and move on. A question precedent already answers is not an open question.

Escalate to Michael only when the ambiguity is a genuine call about *his* priorities or goals that nothing in the repo signals — whether something is worth building at all right now, or a tradeoff between two workflows he might weight differently with no convention or prior art to settle it. This is a narrow bar: "I'm not 100% sure" on an engineering judgment call isn't it.

This standard applies wherever a skill is tempted to stop and ask rather than decide — `dev-team`'s Architect step, `backlog-burndown`'s ambiguous-scope handling, and `skill-review`'s new-skill-idea findings all resolve against it before treating something as blocked on a human.

## Reload

Claude loads skill metadata at session start. After skill edits: start a **new conversation** (or ⌘R in desktop/iTerm).
