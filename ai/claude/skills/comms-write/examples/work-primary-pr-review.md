---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# [work-primary] — PR review request (public stub)

Slack message after opening a GitHub PR for team review.

**Audience:** Peers or admins on the team channel  
**Tone:** Short, scannable, TLDR-first

## What to gather

- PR title, number, URL (`gh pr view` on current branch if not provided)
- One-sentence TLDR from PR body `## Summary` (first bullet) or title
- Jira key from branch name or PR body — build URL from `jira.base_url` in local.json; omit line if no key

## Format

```plain
Hey team — PR ready for review:

*{repo_short} #{number}* — {title}
{url}

*TLDR:* {one sentence, under ~20 words}

Jira: {full jira url or omit this line}
```

## Rules

- Full Jira URL only when key is known — never guess
- Repo short name (e.g. `vault_infra`), not full org path
- Under ~6 lines; no emoji unless asked
- Deliver in a fenced `plain` code block for copy-paste
