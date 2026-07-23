---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-22
updated_by: human
---

# Subagent frontmatter schema

Verified against Claude Code's sub-agents documentation (code.claude.com/docs/en/sub-agents.md), current as of Claude Code v2.1.212+. This corrects a training-deck example that mixed a couple of real fields with one that doesn't exist and one with the wrong shape — see § Not real below before copying an example from a slide.

## Required

- `name` — lowercase-hyphenated identifier; becomes `agent_type` in hooks
- `description` — what Claude reads to decide when to auto-delegate to this subagent; same principle as a skill's `description`

## Optional — add each one to solve a specific problem, not by default

| Field | Values | Use it when |
| --- | --- | --- |
| `model` | `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` (default) | The task needs more or less reasoning depth than the parent session — route cheap formatting/lookup work to `haiku`, reserve `opus` for judgment calls |
| `effort` | `low`, `medium`, `high`, `xhigh`, `max` (availability depends on model) | Fine-tune reasoning depth independent of model choice |
| `maxTurns` | integer | Cap how long an autonomous or background agent can run before it must stop — a runaway guard, not a performance tweak |
| `isolation` | `worktree` | The agent needs to make git changes without touching the working tree it was launched from — runs in a temp worktree branched from the default branch, auto-cleaned up if it makes no changes |
| `background` | `true` / `false` | The agent should run without blocking the main session (this is the default behavior as of v2.1.198+) |
| `memory` | `user`, `project`, `local` | The agent needs to retain what it learned across separate invocations — `project` if it should be checked into the repo for teammates to share, `local` if it's personal/uncommitted |
| `mcpServers` | array of server names or inline definitions | Scope MCP access to exactly what this agent's job requires — least privilege, not "give it everything the parent session has" |
| `tools` | array of tool names (allowlist) | Restrict the agent to a small, explicit tool set |
| `disallowedTools` | array of tool names; supports `mcp__<server>` / `mcp__*` patterns | Hard-block specific tools even if `tools` would otherwise allow them (applied before `tools`). This is the real safety rail — a reviewer agent with `disallowedTools: [Write, Edit]` is *physically incapable* of editing, not just told not to in the prompt |
| `skills` | array of skill names | Preload specific skills' expertise into the subagent's context on spawn |
| `initialPrompt` | string | Auto-submitted as the first turn when this agent is launched as the main session (`claude --agent=<name>`) — not used when delegated to via the Agent tool |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan` | Override the parent session's permission handling for this agent specifically |
| `color` | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` | Cosmetic — distinguishes this agent in the task list/transcript |

## Not real (common misconception)

- **`context: fork`** — there is no such subagent frontmatter field. Forking the current conversation into a bounded sub-task is a separate feature (the `/subtask` command), not something you configure per named subagent. A named subagent starts with a blank context by default, plus whatever `skills`/`memory` it's given — it does not inherit the parent conversation's history.
- **`hooks: [some-name]` shorthand** — hooks are real on a subagent, but they require the same full structured form used in project-level `settings.json` (`PreToolUse`/`PostToolUse`/`Stop` with a `matcher` and a `hooks` array), not a flat list of string names. A shorthand string array won't parse.

## Worked example

A PR-reviewer subagent that can look but not touch, is capped so it can't run away, and only gets the one MCP server it needs:

```yaml
---
name: reviewer
description: Reviews an open PR diff for correctness and style issues. Use when asked to review a PR, sanity-check a diff, or get a second opinion on changes before merge.
model: opus
effort: high
maxTurns: 20
isolation: worktree
background: true
memory: project
mcpServers: [github]
disallowedTools: [Write, Edit]
initialPrompt: "Review the open diff"
---

Flag edge cases the tests don't cover. Check error paths and boundary conditions.
Report findings only — you have no edit tools, so describe the fix in prose
rather than proposing an inline diff.
```

## Deciding what to set

Start minimal: `name` + `description` + a tight `tools` list is a complete, valid subagent. Add fields only to solve a real problem you actually have:

- Cost control needed? → `model` / `effort`
- The agent shouldn't be able to break something? → `disallowedTools` (not just instructions in the prompt body)
- The agent runs autonomously or in the background? → `maxTurns` as a runaway guard
- The agent does git/file work that shouldn't bleed into your working tree? → `isolation: worktree`
- The agent needs to remember something between separate invocations? → `memory`
- The agent needs one specific external system? → `mcpServers`, scoped to just that server — never inherit "everything"
