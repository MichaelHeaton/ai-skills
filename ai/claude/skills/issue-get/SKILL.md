---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
name: issue-get
description: Fetch the full details of a specific task or ticket by ID. Works across Linear, GitHub Issues, and Jira. Use when the user references SR-42, #94, PROJ-12345, or similar.
---





Fetch full details for a specific task from its source system and present them clearly.

## Steps

### 1. Identify the system and ID

Check `~/Projects/personal/memex/Raw/_task-index.jsonl` first — find the record matching the ID.

- If found: use `system` and `repo` fields to know which API to call.
- If not found: infer from the ID format:
  - `SR-NNN` / `LIN-NNN` → Linear (`linear`)
  - `#NNN` or plain integer → GitHub; check index `repo` or detect-context
  - `PROJ-12345` → Work Jira (`jira`)

### 2. Fetch from source system

**Linear:** Use Linear MCP `get_issue` with the identifier.

**GitHub Issues:**

> **Account:** Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment):
>
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```
>
> Always pass `--repo <owner/repo>` explicitly.

```bash
gh issue view {NUMBER} \
  --repo <owner/repo> \
  --json number,title,body,labels,state,url,createdAt,comments
```

**Work Jira:**
Use the Atlassian MCP `jira_get_issue` tool with the ticket key.
See [[Agents/23-jira-rules|23-jira-rules]] for work Jira context (see personal KB Agents/ if present) (Epic ownership, ticket types, Sherlock/FastPass notes).

### 3. Present the result

Show:

- Title and ID/URL
- Current status and labels/priority
- Full issue body (story, acceptance criteria, context links)
- Recent comments (last 3–5 if many)
- Any vault_ref from the task index (link to related vault knowledge note)

### 4. Sync task index if status has drifted

If the live status differs from the index record, update the index line. Linear: `completed`/`canceled` → `closed`.
