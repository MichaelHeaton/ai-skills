---

name: issue-get
description: Fetch the full details of a specific task or ticket by ID. Works across GitHub Issues, GitLab Issues, and Jira. Use when the user references a specific issue number or ticket key (e.g. "#94", "PROJ-XXXXX", "issue 94"), or when another skill needs full context for a task before acting on it.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


Fetch full details for a specific task from its source system and present them clearly.

## Step 0 — Load local config

Read `~/.config/claude-skills/local.yaml` when present ([references/local-config.md](../../../references/local-config.md)).

## Steps

### 1. Identify the system and ID

Check `~/Projects/personal/memex/Raw/_task-index.jsonl` first — find the record matching the ID.
- If found: use `system` and `repo` fields to know which API to call.
- If not found: infer from the ID format:
  - `#NNN` or plain integer → run detect-context to determine which repo (see §2 below)
  - `PROJECT-NNNNN` (employer key prefix) → work Jira (`jira-adobe`) — prefix from `local.yaml` → `jira.project_key`

### 2. Fetch from source system

**Repo unknown — detect it:**
```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```
- `github-current:<repo>` → use that repo
- `gitlab-current:<namespace/repo>` → use that namespace path
- `memex` or no match → default to `${GITHUB_PERSONAL_USER}/memex`

**GitHub Issues:**

> **Account:** Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment):
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```
> Always pass `--repo <owner/repo>` explicitly.

```bash
gh issue view {NUMBER} \
  --repo <owner/repo> \
  --json number,title,body,labels,state,url,createdAt,comments
```

**GitLab Issues:**
```bash
glab issue view {NUMBER} --repo <namespace/repo>
```

**Work Jira:**
Use the Atlassian MCP `jira_get_issue` tool with the ticket key. Follow `jira.epic_owners_note` and team conventions from `local.yaml`.

### 3. Present the result

Show:
- Title and ID/URL
- Current status and labels/priority
- Full issue body (story, acceptance criteria, context links)
- Recent comments (last 3–5 if many)
- Any vault_ref from the task index (link to related vault knowledge note)

### 4. Sync task index if status has drifted

If the live status differs from the index record, update the index line to reflect current status.
