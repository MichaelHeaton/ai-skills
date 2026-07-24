---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: claude
name: issue-triage
description: Audit an oversized ticket, surface overlapping child issues, propose a focused scope split, create the replacement tickets, and close the original. Works across Jira and GitHub Issues. Use when the user says "this ticket is too big, split it", "let's triage PROJ-123", "split PROJ-123 into focused tickets", "audit this epic for overlaps", "this ticket needs to be broken up", or pastes a ticket URL and asks to decompose or scope it.
compatibility: Requires gh CLI (GitHub path) or Atlassian MCP (Jira path).
---

Audit a ticket's scope, identify overlaps, split into focused child tickets, then close the original.

## Steps

### 1. Fetch the ticket

Identify the system from the ID/URL (same logic as `issue-get`). Fetch full details including description, labels, epic/parent, and comments.

### 2. Fetch sibling and child context

**Jira:** `jira_get_project_issues` for the parent epic (or JQL: `"Epic Link" = <key>` / `parent = <key>`).
**GitHub:** fetch issues with the same milestone or parent tracking issue.

List all sibling/child tickets. Identify:

- Tickets that duplicate or overlap the target scope
- Tickets that are already superseded by newer work
- Tickets that are so broad they contain multiple independent deliverables

### 3. Propose a split

Present the proposed split to the user before creating anything:

```
## Triage: <ORIGINAL-KEY> — <title>

### Problem
<Why this ticket is too broad — e.g., "covers both X and Y, no single owner">

### Proposed split

1. **<short title>** — <one-line scope>
   AC: <key acceptance criteria>

2. **<short title>** — <one-line scope>
   AC: <key acceptance criteria>

### Overlapping tickets
- <KEY>: <title> — <recommended action: close / merge into #1 / keep>
```

Ask: "Does this split look right, or do you want to adjust before I create the tickets?"

### 4. Create child tickets

Once confirmed, create each child ticket using the `issue-create` skill logic (same routing: Jira → Path A, GitHub → Path B/C). Link each new ticket back to the original in its Context section.

### 5. Update and close the original

Add a comment to the original ticket:

```
Decomposed into focused tickets:
- <KEY-or-#N>: <title> (<url>)
- <KEY-or-#N>: <title> (<url>)

Closing original as superseded.
```

Then close the original. For Jira: `jira_transition_issue` to Done/Won't Do. For GitHub: `gh issue close`.

Update the task index: mark original `closed`, add new tickets as `open`.

### 6. Confirm

Report:

- Original ticket: closed ✓
- Created: list of new ticket IDs and URLs
- Overlapping tickets actioned (if any)
