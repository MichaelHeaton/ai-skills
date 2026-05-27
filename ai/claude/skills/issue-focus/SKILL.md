---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: issue-focus
description: Load a Jira ticket or GitHub Issue into a focused working session. Fetches the ticket, presents a structured brief (narrative summary, acceptance criteria checklist, current status, recent comments, linked epic), asks which ACs are already done, then stays active so you can ask "what's next?", "am I done?", or "what did the last comment say?" throughout the session. Use when starting work on a specific ticket, when you need a quick orientation before diving in, or when you want to stay on track mid-session. Triggers on: "focus on PROJ-12345", "load ticket #94", "start a session for PROJ-12345", "brief me on this ticket", a bare Jira key like PROJ-12345, or a GitHub issue URL.
compatibility: Jira requires Atlassian MCP. GitHub requires gh CLI with GITHUB_PERSONAL_USER set.
---



# Issue Focus

Load a ticket and keep it in context for the entire working session. The brief surfaces everything you need to start — the goal, what done looks like, current state, and recent decisions — then asks which ACs you've already completed so the checklist reflects reality from the first message.

## Step 1 — Identify the system and type

| Input format | System | Type |
|---|---|---|
| `PROJ-12345` or `PROJECT-XXXXX` | Jira | Story/Task |
| `github.com/.../issues/NNN` | GitHub | Issue |
| `#NNN` or bare integer | Check task index → detect-context.sh | — |

For `#NNN` without a URL: check `~/Projects/personal/memex/Raw/_task-index.jsonl` by `id` first. If found, use the `system` and `repo` fields. If not found, run:

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

## Step 2 — Fetch the ticket

**Jira** — use Atlassian MCP:
- `jira_get_issue` for the ticket body, status, assignee, labels, epic link
- `jira_add_comment` is available later if the user wants to update the ticket during the session

**GitHub:**
```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
gh issue view {NUMBER} \
  --repo {owner/repo} \
  --json number,title,body,labels,state,url,createdAt,comments,milestone
```

## Step 3 — Build the session brief

Present in this order. Lead with the header so the ticket identity is visible at a glance.

### Header
```
## Focus: {TICKET-ID} — {title}
**Status:** {state}  |  **Assignee:** {assignee}  |  **Epic/Milestone:** {parent title or —}
```

### The goal
2–3 sentences: what this ticket is trying to accomplish, any key constraints from the description, and why it matters in context. Write as orientation, not a title restatement.

### Acceptance Criteria
Extract AC items from the description — look for bullet lists under an "Acceptance Criteria" or "AC" heading, or checkbox items. Present all as unchecked initially:

```
- [ ] 1. AC item one
- [ ] 2. AC item two
- [ ] 3. AC item three
```

Number them so the user can refer to them by number. If no explicit ACs exist, derive 2–3 from the description and label them `(inferred)`.

### Recent activity
Summarize the last 3–5 comments in one line each:
```
- [Date] [Author]: brief summary
```

### Open Blockers / Questions
Extract any unresolved blockers or open questions from the comments. Number them so the user can respond by number:
```
1. Awaiting response from Ben on raft resync behavior — gates the AMER DR CMR
2. Runbook update staged but not yet merged/published
```
Omit this section if there are no open items.

### Linked items
List any linked epic, parent, or blocking issues by key and title. Omit if none.

---

## Step 4 — Ask which ACs are done

After presenting the brief, ask:

> Which of these ACs have you already completed? Give me the numbers (e.g. "1 and 3") or say "none" to start fresh.

Update the checklist with `[x]` for any items they confirm complete. Show the updated checklist.

Then open the session:

> **Session open** — ask me anything about this ticket. Try: "what's next?", "am I done?", or "refresh from {system}".

## Step 5 — Stay active

For the rest of the conversation, treat the ticket as live context. Re-fetch only when the user explicitly asks for a refresh.

| User says | Response |
|---|---|
| A bare number (e.g. "1") | Treat as a response to the correspondingly numbered blocker/question — ask what their answer or update is, then offer to post it as a comment |
| "what's next?" | First unchecked AC item |
| "am I done?" | Review the checklist — list what's checked and what's open |
| "mark AC 2 done" / "done with 2" | Update `[ ]` → `[x]` for that item and confirm |
| "what did [person] say?" | Pull from the recent activity summary |
| "refresh" / "reload" | Re-fetch the ticket and rebuild the brief; re-ask which ACs are done |
| "update status" / "transition" | For Jira: use `jira_transition_issue`. For GitHub: guide them to close or update labels |
| "add a comment" | Use the appropriate API tool or CLI to post a comment |
| "close session" / "done for now" | Summarize: which ACs were completed this session, any open items, and suggest next steps |
