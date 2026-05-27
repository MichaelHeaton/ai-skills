---

name: issue-update
description: Update a task or ticket — change status, add a comment, edit labels, close it, or sync the task index. Works across GitHub Issues, GitLab Issues, and Jira. Use when the user says "close issue #X", "mark PROJ-12345XXXX done", "add a comment to #X", "update the priority on", or any similar task update request.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


Update an existing task in its source system and keep the task index in sync.

## Description edit policy

The description is the definition of done — it should always be accurate, but changes need handling deliberately. This policy applies to all systems (GitHub, GitLab, Jira).

| Situation | Action |
|---|---|
| Progress, decisions, blockers, status updates | **Comment only** — never edit the description |
| Typo, wrong word, missing AC that was always intended | **Silent edit** — correct it, no comment needed |
| Substantive rewrite (wrong role, wrong goal, missing scope) | **Edit + audit comment** — see format below |
| Scope splits into multiple deliverables | **Close + new tickets** — close original with a comment linking to the replacement(s) |

When in doubt, add a comment rather than editing.

**Audit comment format** (substantive rewrites only):

```
**Description updated** — YYYY-MM-DD
Changed: [what section changed]
Old: [key phrase or full old text if short]
Reason: [why the original was wrong]
```

## Steps

### 1. Identify the task

Look up the task in `~/Projects/personal/memex/Raw/_task-index.jsonl` by ID. Get the `system`, `repo`, and `url`.

If not in the index, infer system from ID format:
- `#NNN` or integer → run `scripts/detect-context.sh` (see issue-create) to find the repo; default `${GITHUB_PERSONAL_USER}/memex`
- `PROJ-12345` → Jira (`jira-work`)

### 2. Perform the requested update

#### GitHub Issues (Memex or personal repos)

> **Account:** Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment):
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```
> Always pass `--repo <owner/repo>` explicitly — the SSH alias on Memex's remote confuses `gh`.

```bash
# Close
gh issue close {NUMBER} --repo {owner/repo} \
  --comment "Done: {one-line summary of what was completed}"

# Comment
gh issue comment {NUMBER} --repo {owner/repo} --body "{comment text}"

# Edit labels
gh issue edit {NUMBER} --repo {owner/repo} \
  --add-label "priority/high" --remove-label "priority/low"

# Edit description (apply description edit policy — audit comment required for substantive rewrites)
gh issue edit {NUMBER} --repo {owner/repo} --body "{updated body}"

# Reopen
gh issue reopen {NUMBER} --repo {owner/repo}
```

#### GitLab Issues

Use the `glab` CLI. The `--repo` value is the full namespace path from the task index `repo` field (e.g. `specterrealm/esports/minecraft/minecraft-modpack-cp-verdant`).

```bash
# Close
glab issue close {NUMBER} --repo {namespace/repo}

# Comment
glab issue note {NUMBER} --repo {namespace/repo} --message "{comment text}"

# Edit title
glab issue update {NUMBER} --repo {namespace/repo} --title "{new title}"

# Edit description (apply description edit policy — audit comment required for substantive rewrites)
glab issue update {NUMBER} --repo {namespace/repo} --description "{new body}"
glab issue note {NUMBER} --repo {namespace/repo} --message "**Description updated** — YYYY-MM-DD\nChanged: ...\nOld: ...\nReason: ..."

# Reopen
glab issue reopen {NUMBER} --repo {namespace/repo}
```

#### Jira

Use the Atlassian MCP tools:
- `jira_add_comment` — for status updates, blockers, decisions, and audit comments on description rewrites
- `jira_transition_issue` — to change Jira workflow status
- `jira_update_issue` — for field changes (priority, due date) and description rewrites (apply description edit policy)

See [[Agents/23-jira-rules|23-jira-rules]] for work Jira conventions (private vault rules).

### 3. Sync task index

After any status change, update `~/Projects/personal/memex/Raw/_task-index.jsonl`:
- **Closed/resolved** → rewrite the matching line with `status: "closed"`
- **Reopened** → rewrite with `status: "open"`
- **No status change** (comment, label update) → no index change needed

To update: read the file, find the matching line by `id`, rewrite it with the updated `status`, write the file back.

### 4. Confirm to the user

Report what changed:
- "Closed [#94](url) — task index updated."
- "Added comment to PROJ-12345."
- "Updated priority on [#95](url) to high."
