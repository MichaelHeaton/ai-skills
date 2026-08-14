---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# User story template

```markdown
## Story
As a [role], I want [goal], so that [outcome].

## Acceptance Criteria
- [ ] [Criterion — what does done look like?]

## Test Plan
- [ ] [Concrete step, command, or scenario that proves the fix works — not "code review looks right"]

## Context & Links
- Vault: [link to relevant vault note, if any]
- Reference: [external URL, doc, or wiki link, if any]

> Add updates and blockers as comments, not edits to this body.
```

## Role rules

Use the hat the user is wearing — never "As I, I want".

| Domain | Role |
| ------ | ---- |
| `adobe` | "an SRE" or "a Vault team lead" |
| `uv-cyber` | "a UV Cyber director" |
| `homelab` | "a homelab operator" |
| `learning` | "an engineer upskilling on AI tooling" |
| `mtb` | "an MTB coach" |
| `personal` | "a parent" or "a family organizer" |

Safe default: "an SRE and knowledge worker"

- Acceptance criteria are required — minimum one line
- Test plan is required — minimum one concrete, checkable step (a command to run, an input/output pair, a scenario to exercise). Not satisfied by "review the code" or "looks correct" — those aren't executable. If the ticket is pure research/docs with no behavior to verify, write "N/A — no executable behavior" explicitly rather than omitting the section.
- Omit Context & Links lines with nothing to fill in
