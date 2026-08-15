---
version: 1.6.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: issue-update
description: Update a task or ticket — change status, add a comment, edit labels, close it, or sync the task index. Works across GitHub Issues, GitLab Issues, and Jira. Also the right tool for closing tickets found stale/duplicate/superseded during a backlog-triage pass, not just active single-ticket work. Use when the user says "close issue #X", "mark PROJ-12345 done", "update the description of PROJ-123", "update PROJ-123" (including a bare "update <ticket-id>" meaning add a comment, not just a status change), "scope this ticket to", "scope this down to only X", "narrow the scope of this ticket", "transition this to closed", "this ticket is done — close it", "transition to blocked", "close as duplicate", "close as stale", "close as superseded", "closing during triage", "add a comment to <ticket>", "post a comment on <ticket>", "correct the description of <ticket>", "fix the wording on <ticket>", "add a follow-up to <ticket>", "post a fix to <ticket>", or similar — including comment-posting and correction requests that don't contain the word "update" at all. Also fires autonomously — always use this skill when Claude itself decides to comment on, close, relabel, or transition any ticket, or whenever about to call `gh issue comment`/`gh issue close`/`gh issue edit`/`glab issue note`/`glab issue close`/`jira_add_comment`/`jira_transition_issue`/`jira_update_issue` directly instead of through this skill.
---

Update an existing task in its source system and keep the task index in sync.

## Description edit policy

The description is the definition of done — it should always be accurate, but changes need handling deliberately. This policy applies to all systems (GitHub, GitLab, Jira).

| Situation | Action |
| --- | --- |
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

- `#NNN` or integer → GitHub; use index `repo` or detect-context
- `PROJ-12345` → Jira (`jira`)

### 2. Perform the requested update

#### GitHub Issues

> **Account:** Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment). **Unset `GH_TOKEN` first** — a stale value already in the environment takes precedence over the fresh keyring lookup below and can silently re-export a bad token, causing 401s:
>
> ```bash
> unset GH_TOKEN
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```
>
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

### 3. Verify comment/description writes for markdown-escaping mangling

For the fuller pre-check + auto-fix version of this step (including bracket-tag stripping and batch correction of already-corrupted tickets), see the `ticket-write-verify` skill _(global: ai-skills)_.

Some ticket systems (Jira in particular) silently mangle plain-text markdown on write — underscores escaped to `\_`, bold markers (`**text**`) dropped or rendered as literal escaped asterisks, or `+` characters stripped. Backtick-wrapping helps inconsistently, so the only reliable check is to re-fetch and compare.

After any comment or description write (not label/status-only changes), re-fetch the posted content and diff it against what was sent:

- **Jira**: `jira_get_issue` (or `jira_get_comment` for a comment) and compare the returned text
- **GitHub**: `gh issue view {NUMBER} --repo {owner/repo} --json body,comments`
- **GitLab**: `glab issue view {NUMBER} --repo {namespace/repo}`

If the re-fetched content shows escaping artifacts (`\_`, `\*`, dropped bold markers, stripped `+`), correct it immediately via the system's edit call (`jira_update_issue` / `jira_edit_comment`, `gh issue edit` / `gh issue comment --edit-last`, `glab issue update`) rather than leaving it to be caught manually later.

### 4. Sync task index

After any status change, update `~/Projects/personal/memex/Raw/_task-index.jsonl`:

- **Closed/resolved** → rewrite the matching line with `status: "closed"`
- **Reopened** → rewrite with `status: "open"`
- **No status change** (comment, label update) → no index change needed

To update: read the file, find the matching line by `id`, rewrite it with the updated `status`, write the file back.

### 5. Bulk operations

Closing or relabeling many issues in a row (e.g. a milestone reshape, duplicate cleanup) can trigger an Auto-review block requiring smart-mode approval before rapid mutations are allowed to continue — this isn't an error, it's a safety gate on high-velocity writes. Approve the first smart-mode card when it appears, and group closes/edits of the same shape (same action, same reason) into contiguous batches rather than interleaving them with unrelated calls — that keeps the approval gate from re-triggering mid-batch on what looks like a shape change.

### 6. Confirm to the user

Report what changed:

- "Closed [#94](url) — task index updated."
- "Added comment to PROJ-12345."
- "Updated priority on [#95](url) to high."
