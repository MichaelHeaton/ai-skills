---
version: 1.1.3
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: issue-get
description: Fetch the full details of a specific task or ticket by ID. Works across GitHub Issues and Jira. Use when the user references #94, PROJ-12345, or similar — or pastes a bare ticket URL (GitHub or Jira).
---

Fetch full details for a specific task from its source system and present them clearly.

## Steps

### 1. Identify the system and ID

Check `~/Projects/personal/memex/Raw/_task-index.jsonl` first — find the record matching the ID.

- If found: use `system` and `repo` fields to know which API to call.
- If not found: infer from the ID format or URL:
  - `#NNN` or plain integer → GitHub; check index `repo` or detect-context
  - `PROJ-12345` → Work Jira (`jira`)
  - `https://github.com/<owner>/<repo>/issues/<N>` → GitHub; extract `owner/repo` and issue number
  - `https://*.atlassian.net/browse/<KEY>-<N>` → Jira; extract ticket key

### 2. Fetch from source system

**GitHub Issues:**

> **Account:** Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment). **Unset `GH_TOKEN` first** — a stale value already in the environment takes precedence over the fresh keyring lookup below and can silently re-export a bad token, causing 401s (parity with `issue-update`):
>
> ```bash
> unset GH_TOKEN
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> [[ -n "$GH_TOKEN" ]] || echo "gh auth token returned empty — this may be a broken keyring backend, not a wrong account; try 'gh auth refresh' or check Keychain Access directly" >&2
> ```
>
> That empty-token check is a keyring-health check, distinct from the stale-`GH_TOKEN` case above it — an empty result here means the keyring backend itself failed the lookup, not that a stale env var shadowed a good token (that's already handled by the `unset` on the line before).
>
> A third, distinct case is a **wrong active account**: `gh auth token` can succeed and return a non-empty value, yet the `gh issue view` call below still fails with an authorization- or not-found-style error, because the active `gh` account simply doesn't have access to the target repo. This is neither the keyring failure above (the token lookup worked fine) nor the stale-env-var case (a fresh token was exported) — don't reach for a keyring refresh here. Resolve it with the `gh-account-routing` skill (global: ai-skills).
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

If the live status differs from the index record, update the index line.
