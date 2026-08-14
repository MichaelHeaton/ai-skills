---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Sub-agent invocation pattern

**Scope**: the `skill-reviewer` subagent exists for skill-review's own SA2–SA4 audits only — a fresh-context pass over specific skills' `SKILL.md` files. It is not a general-purpose delegation target for unrelated work (live user-negotiation, ticket-scoping conversations, or anything outside a skill-hygiene audit), even when a task happens to come up mid-session alongside a skill review.

Run SA2–SA4 inside a sub-agent when you want fresh skill file reads mid-session (sub-agents reload all SKILL.md files from disk at startup) or when the accumulated session context would distort the audit.

**Division of labor:**

- **Parent session** — does SA1 (has the conversation history), then delegates to a sub-agent
- **Sub-agent** — receives the SA1 output as structured input, runs SA2–SA4, returns findings table
- **Parent session** — handles SA5 (ticket creation, security scrub)

**Preferred sub-agent**: the named `skill-reviewer` subagent (Agent tool, `subagent_type: skill-reviewer`, defined in `ai/claude/agents/skill-reviewer.md`) already has `skills: [skill-review]` preloaded and runs in its own isolated context — use it instead of an ad-hoc general-purpose Agent call. If it isn't deployed on this machine, fall back to a general-purpose Agent with the prompt template below.

**What the parent must pass to the sub-agent:**

```
## Session context (from parent)

Session focus: [one sentence]
Skills active this session:
- <skill-name> (global: ai-skills)
- <skill-name> (project: <repo-name>)
Friction observed: [bullet list — what went wrong or felt off]

## Your task

Run skill-review session-audit steps SA2–SA4.
SA1 is complete — use the context above as input.
Read ~/.claude/skills/{name}/SKILL.md fresh for each skill listed.
Return ONLY the findings table, new skill ideas table, and a one-paragraph summary.
Do NOT run SA5. Do NOT create tickets.
```

**Output format the sub-agent should return:**

```
### Findings Table
| Skill | Finding | Type | Proposed Change | Priority |
| skill-X | [text] | friction|gap|clean | [change or "none"] | high|medium|low |

### New Skill Ideas
| Proposed Name | One-line Description |

### Summary
[1–2 sentences]
```

**Security note**: SA5's security scrub applies to the **parent session** when it acts on findings — not the sub-agent itself. The sub-agent returns findings; the parent creates tickets and must run the scrub.
