---

name: comms-write
description: Write internal communications for work-primary or client-contract domains. Covers status updates, 3P updates, incident reports, customer notifications, leadership updates, PR review Slack posts, and general internal messaging. Use for team updates, status reports, incident summaries, stakeholder messages, or Slack posts (including after opening a PR). Triggers on "write a 3P", "status update", "incident report", "PR ready for review", "slack message for PR", "/pr-slack", "draft PR notification", "send to vault admins", "slack message", "post to slack", "message for the team", "write comms for", "draft a message to".
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# Comms Write

Write polished internal communications. Before writing, identify:

1. **Domain context** — `work-primary` or `client-contract` (from conversation or `local.json`)
2. **Communication type** — see routing table below

Load the example file from the **resolved examples directory** (see below), then follow its instructions.

---

## Resolve examples directory

Use the **first path that exists**:

1. `comms_write.examples_root` in `~/.config/ai-skills/local.json` (absolute path to `.../examples/`)
2. `comms_write.memex_repo_path` + `comms_write.examples_relative` from `local.json` (personal KB layout)
3. Personal KB repo: `ai/claude/skills/comms-write-context/examples/` (tracked path when vault is the project)
4. Fallback: `examples/` in this skill directory (public stubs only)

If private examples exist, prefer them over stubs. Do not commit private example content into the public skills repo.

---

## Routing

| Type | Domain | File (under resolved examples dir) |
|------|--------|-------------------------------------|
| 3P update (Progress / Plans / Problems) | work-primary | `work-primary-3p.md` |
| Incident report or post-mortem | work-primary | `work-primary-incident.md` |
| Customer notification | work-primary | `work-primary-customer-notify.md` |
| Leadership or stakeholder update | work-primary | `work-primary-leadership.md` |
| PR review request (Slack, after `gh pr create`) | work-primary | `work-primary-pr-review.md` |
| Any internal comms | client-contract | `client-contract-general.md` |

For PR review messages: run `gh pr view --json number,title,url,body,headRefName` when no PR URL was given. Prefer this skill over a separate PR-only skill — one comms entry point.

If the type is unclear, ask: "What type of communication is this — status update, incident report, customer notification, or something else?"

If domain context is unclear, ask or infer from `local.json` / current repo.

---

## General principles

- Lead with the most important information — readers skim
- Active voice, concrete details, no filler
- Match tone to audience: leadership = outcome-focused; customer = empathetic and actionable
- Pull from Jira, Slack, or other tools when available
- When in doubt, shorter is better
- **Deliver the draft in a fenced code block** — use ` ```plain ` so the user can copy into Slack without reformatting
