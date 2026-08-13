---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Ticket cross-referencing (Step 9 detail)

Do not ask the user if they worked on tickets. Instead, find them from the index and the session's git activity.

**Step 9a — Load open tickets from the index**

```bash
grep '"status":"open"' ~/Projects/personal/memex/Raw/_task-index.jsonl \
  | python3 -c "import sys,json; [print(json.loads(l)['system'], json.loads(l)['id'], json.loads(l)['title']) for l in sys.stdin]"
```

**Step 9b — Cross-reference against this session's git work**

For each repo worked in this session, scan recent commit messages, branch names, and PR titles for ticket IDs:

```bash
git -C <repo> log --oneline --since="12 hours ago"
```

Look for patterns like `PROJ-12345`, `PROJ-###`, `#94`, or ticket keywords matching index titles.

**Step 9c — Verify the PR actually references the ticket**

A branch name or commit message matching a ticket ID in Step 9b is a candidate, not confirmation — before asserting "PR #N relates to TICKET-X" anywhere (a ticket comment, the closing note, or the Step 10 session summary), confirm the PR itself actually references that ticket key:

```bash
gh pr view <PR> --repo <owner/repo> --json title,body,commits \
  --jq '.title, .body, (.commits[].messageHeadline)'
```

Check the output for the ticket key. If it's not found, do not assert the linkage as settled fact — either omit the PR from that ticket's update entirely, or note it as "possibly related, unverified" and let the user confirm. A branch/commit-message match without a PR-text match is exactly the false-positive case this check exists for (a stale or unrelated PR sharing a naming coincidence with the ticket).

**Step 9d — Act on matches**

For each open ticket that matches session activity (and, for PR-linked updates, passed the Step 9c verification):

- If work is **done** → transition to Done/Closed or add a closing comment
- If work is **in review** (PR open, verified) → update status to "In Review", add PR link in comment
- If work is **paused** → add a comment with where things stand so the next session picks up cleanly
- If work is **blocked** → add a blocker comment and transition to Blocked

**Ordering — always comment before transitioning, for every ticket system (Jira, Linear, GitHub):**

1. Add the comment (closing note, status update, PR link, etc.)
2. Verify the comment was created (check the response from the MCP or CLI)
3. Then transition the status

Never run the comment and transition in parallel. A failed comment on a closed ticket has no audit trail — the ticket closes without context, which is worse than leaving it open. If the comment fails, keep the ticket open and flag it in the session summary.

For Jira: call `jira_get_transitions` first to get valid transition IDs (never guess — IDs vary per project), then `jira_add_comment` → `jira_transition_issue`. For GitHub: `gh issue comment` → `gh issue close`. For Linear: `save_comment` → `save_issue`. Update `status` in `_task-index.jsonl` to reflect the new state.
