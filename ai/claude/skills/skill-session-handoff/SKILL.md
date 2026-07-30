---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
name: skill-session-handoff
description: Package the current session's skill activity and friction notes into a structured context block ready to pass to a sub-agent. Produces the SA1 output block that skill-review's sub-agent invocation pattern requires — run this in the parent session before spawning a sub-agent to run skill-review SA2–SA4. Also the right tool whenever the user just wants a self-contained context block to resume in a fresh session, not only ahead of a skill-review delegation. Triggers on: "package session skills for sub-agent", "build handoff block", "prepare skill context", "summarize session skills", "I'm about to spawn a skill-review sub-agent", "build the sub-agent context", "prep the handoff", "wrap up skills", "skill hygiene", "prep for skill review", "let's do skills before we close", "end of session skill stuff", "handoff prompt", "next session context", "where to pick up", "context for next session", "prompt for the next session", "start back up on this", or when skill-review's sub-agent pattern calls for an SA1 context block from the parent.
---

# Skill Session Handoff

Produces a structured context block from the current session's skill activity. The output matches the handoff contract in skill-review's "Sub-agent invocation pattern" section — paste it directly as context when spawning a sub-agent to run skill-review SA2–SA4.

## 1. Identify skills used

Reflect on the current conversation. List every Skill tool invocation and every place a skill was named and executed.

## 2. Assess each skill briefly

For each skill that ran:

- Did it trigger without the user having to ask explicitly?
- Was there a correction loop (user redirected mid-execution)?
- Did it route correctly (right repo, right system, right output format)?

Flag only skills with friction — "no friction" is a valid result.

## 3. Identify ungapped workflows

Look for multi-step work that ran without a skill — patterns that recurred or the user said they do regularly.

## 4. Assemble the context block

Output the following block, filled in from steps 1–3. This must match `references/sub-agent-pattern.md` (in `skill-review`) exactly, field for field — a flatter or reworded version breaks the sub-agent's reception logic and forces it to re-derive each skill's source instead of reading it off the block:

```
## Session context (from parent)

Session focus: [one sentence — not a paragraph, not a narrative]
Skills active this session:
- <skill-name> (global: ai-skills)
- <skill-name> (project: <repo-name>)
Friction observed: [bullet list — what went wrong or felt off, or "none"]

## Your task

Run skill-review session-audit steps SA2–SA4.
SA1 is complete — use the context above as input.
Read ~/.claude/skills/{name}/SKILL.md fresh for each skill listed.
Return ONLY the findings table, new skill ideas table, and a one-paragraph summary.
Do NOT run SA5. Do NOT create tickets.
```

**Keep "## Your task" as its own section, separate from the structured fields above it** — don't interleave delegation prose into "Session focus" or "Friction observed." Each skill gets its own line with a `(global: ai-skills)` or `(project: <repo>)` source annotation, not a flat comma-separated list.

If this handoff is being generated standalone (not ahead of a skill-review delegation — e.g. the user just asked for a context block to resume in a fresh session), the "## Your task" section can be replaced with whatever the user actually needs the next session to do; the structured "Session context" fields above it stay the same either way.

## 5. Offer next step

After outputting the block, ask:

> → Ready to delegate this to the `skill-reviewer` subagent. Want me to do that now?

If yes: use the Agent tool with `subagent_type: skill-reviewer` and the block above as the task prompt — it already has `skills: [skill-review]` preloaded and runs SA2–SA4 in its own isolated context. The Agent tool is a primary tool and should be available without any schema loading step. If `skill-reviewer` isn't deployed on this machine, fall back to a general-purpose Agent following the prompt template in skill-review's "Sub-agent invocation pattern" section. If neither responds, tell the user and ask them to copy the block into a new conversation manually.
