---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-06-18
updated_by: human
---

# [work-primary] — PR review request (public stub)

Slack message after opening a GitHub PR for team review.

**Audience:** Peers or admins on the team channel
**Tone:** 1–2 lines max — PR link first, nothing else needed

## What to gather

- PR title, number, URL (`gh pr view` on current branch if not provided)
- Jira key from branch name or PR body — build URL from `jira.base_url` in local.json; omit if no key

## Format

```plain
:pr: PR ready for review: *{repo_short} #{number}*
* {title}
* {url}
* Jira: {full jira url}
```

Omit the `* Jira:` line if no key is known.

## Rules

- **4 lines max** — header + 3 bullets
- No TLDR section, no status summary — details belong in the PR itself
- Full Jira URL only when key is known — never guess
- Repo short name (e.g. `vault_infra`), not full org path
- Always include the `:pr:` emoji on the header line
- Deliver in a fenced `plain` code block for copy-paste
