---

name: skill-session-handoff
description: Package the current session's skill activity and friction notes into a structured context block ready to pass to a sub-agent. Produces the SA1 output block that skill-review's sub-agent invocation pattern requires — run this in the parent session before spawning a sub-agent to run skill-review SA2–SA4. Triggers on: "package session skills for sub-agent", "build handoff block", "prepare skill context", "summarize session skills", "I'm about to spawn a skill-review sub-agent", "build the sub-agent context", "prep the handoff", "wrap up skills", "skill hygiene", "prep for skill review", "let's do skills before we close", "end of session skill stuff", or when skill-review's sub-agent pattern calls for an SA1 context block from the parent.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
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

Output the following block, filled in from steps 1–3. Use this exact format — skill-review's sub-agent reception logic matches on it.

```
## Session context (from parent)

Session focus: [one sentence describing what this session was about]

Skills active this session: [skill-a, skill-b, ...]

Friction observed:
- [skill-name]: [what went wrong — quote the friction if possible]
(or: none)

Ungapped workflows:
- [description of repeatable pattern that has no skill]
(or: none)
```

## 5. Offer next step

After outputting the block, ask:

> → Ready to spawn a skill-review sub-agent with this context. Want me to do that now?

If yes: use the Agent tool with the block above as the context section, following the prompt template in skill-review's "Sub-agent invocation pattern" section. The Agent tool is a primary tool and should be available without any schema loading step. If it's not responding, tell the user and ask them to copy the block into a new conversation manually.
