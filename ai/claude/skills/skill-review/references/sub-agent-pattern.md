---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: human
---



# Sub-agent invocation pattern

Run SA2–SA4 inside a sub-agent when you want fresh skill file reads mid-session (sub-agents reload all SKILL.md files from disk at startup) or when the accumulated session context would distort the audit.

**Division of labor:**

- **Parent session** — does SA1 (has the conversation history), then spawns a sub-agent
- **Sub-agent** — receives the SA1 output as structured input, runs SA2–SA4, returns findings table
- **Parent session** — handles SA5 (ticket creation, security scrub)

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
