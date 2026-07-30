---
version: 1.4.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
name: comms-write
description: Write internal communications for work-primary or client-contract domains. Covers status updates, 3P updates, incident reports, customer notifications, leadership updates, PR review Slack posts, Slack thread replies, and general internal messaging. Also handles editing or improving an existing draft when pasted inline. Use for team updates, status reports, incident summaries, stakeholder messages, or Slack posts (including after opening a PR). Triggers on "write a 3P", "status update", "incident report", "PR ready for review", "slack message for PR", "/pr-slack", "draft PR notification", "send to vault admins", "slack message", "post to slack", "message for the team", "write comms for", "draft a message to", "update this message", "edit this draft", "polish this", "clean up this slack message", "improve this message", "reply to slack thread", "slack response", "thread reply", "respond to this thread", "draft a reply to this", "slack thread response".
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

**Confirm the routed file actually exists** in the resolved directory before drafting. If it's missing, say so explicitly and ask for a real example to work from rather than freelancing a format — a routed-but-absent file produces a draft with no anchor to what past real output actually looked like.

---

## Routing

| Type | Domain | File (under resolved examples dir) |
| ------ | -------- | ------------------------------------- |
| 3P update (Progress / Plans / Problems) | work-primary | `work-primary-3p.md` |
| Incident report or post-mortem | work-primary | `work-primary-incident.md` |
| Customer notification | work-primary | `work-primary-customer-notify.md` |
| Leadership or stakeholder update | work-primary | `work-primary-leadership.md` |
| PR review request (Slack, after `gh pr create`) | work-primary | `work-primary-pr-review.md` |
| Slack thread reply | any | *(see Thread Reply section below)* |
| Team channel update / FYI post (informal, no ask, no 3P structure) | work-primary | `work-primary-3p.md` *(shares the 3P template — keep it to bullets + one ask, not the full Progress/Plans/Problems structure)* |
| Any internal comms | client-contract | `client-contract-general.md` |

For PR review messages: run `gh pr view --json number,title,url,body,headRefName` when no PR URL was given. Prefer this skill over a separate PR-only skill — one comms entry point.

If the type is unclear, ask: "What type of communication is this — status update, incident report, customer notification, or something else?"

---

## Thread Reply

When the user is drafting a reply to an existing Slack thread (trigger: "reply to slack thread", "thread reply", "respond to this thread", etc.):

1. **Acknowledge context** — open with a one-line summary of what you're replying to: *"Re: [original ask/topic]"* (internal only — strip before pasting if not needed)
2. **Match thread tone** — scan any pasted thread content; mirror formality, length, and emoji/no-emoji style already in the thread
3. **Keep it short** — thread replies are shorter than top-level posts; default to 3–5 lines max unless the question demands more
4. **Deliver in a fenced code block** (` ```plain `) same as other comms types so the user can copy-paste directly

If domain context is unclear, ask or infer from `local.json` / current repo.

---

## General principles

- Lead with the most important information — readers skim
- Active voice, concrete details, no filler
- Match tone to audience: leadership = outcome-focused; customer = empathetic and actionable
- Pull from Jira, Slack, or other tools when available
- When in doubt, shorter is better
- **Before delivering, invoke the `humanizer` skill** on the drafted text — strips AI-writing tells (puffery, canned phrasing, formulaic endings) while preserving every fact and detail exactly. **Skip this for short/structured drafts** — thread replies, PR-review posts, or anything under ~50-75 words or mostly bullets/URLs/ticket references — where a full humanizer pass reliably finds nothing to change but still pays the full token cost of reprinting its instructions. Keep it for longer prose forms (status updates, incident reports, leadership/customer comms) where AI-tell density is actually likely.
- **Deliver the draft in a fenced code block** — use ` ```plain ` so the user can copy into Slack without reformatting
