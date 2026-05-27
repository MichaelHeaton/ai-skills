---

name: comms-write
description: Write internal communications for Adobe/CES or Ultraviolet Cyber (UV). Covers status updates, 3P updates (Progress/Plans/Problems), incident reports, customer notifications, leadership updates, Slack messages, and general internal messaging. Use when asked to write any internal comms, team update, status report, incident summary, stakeholder message, or Slack post. Triggers on: "write a 3P", "status update", "incident report", "customer notification", "team update", "leadership update", "weekly update", "write comms for", "draft a message to", "slack message", "slack update", "make a slack message", "post to slack", "message for the team", "update the team".
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# Comms Write

Write polished internal communications for Adobe/CES or UV. Before writing, identify:

1. **Company context** — Adobe/CES or UV?
2. **Communication type** — see routing table below

Then load the appropriate example file and follow its instructions.

---

## Routing

| Type | Company | File |
|---|---|---|
| 3P update (Progress / Plans / Problems) | Adobe / CES | `examples/adobe-3p.md` |
| Incident report or post-mortem | Adobe / CES | `examples/adobe-incident.md` |
| Customer notification | Adobe / CES | `examples/adobe-customer-notify.md` |
| Leadership or stakeholder update | Adobe / CES | `examples/adobe-leadership.md` |
| Any internal comms | UV | `examples/uv-general.md` |

If the type isn't clear, ask one question: "What type of communication is this — a status update, incident report, customer notification, or something else?"

If the company context isn't clear from the conversation, ask.

---

## General Principles

These apply regardless of template:

- Lead with the most important information — readers skim
- Active voice, concrete details, no filler
- Match the tone to the audience: leadership updates are crisp and outcome-focused; customer notifications are empathetic and action-oriented
- If pulling from Jira, Slack, or other tools, do so — concrete data beats summaries
- When in doubt, shorter is better
- **Deliver the draft in a fenced code block** — use ` ```plain ` so the user can copy and paste directly into Slack without reformatting artifacts
