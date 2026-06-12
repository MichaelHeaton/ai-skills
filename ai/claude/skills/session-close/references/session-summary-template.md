---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: human
---



# Session summary template

```
## Session Close — [date]

### ✓ Clean
- <repo> — all changes committed and pushed
- <ticket> — closed/transitioned

### → Open PRs (needs review/merge)
- <repo>/<branch> — PR #N: <title>

### ⚠️ Pending (needs attention next session)
- <repo> — <what was left and why>
- <ticket> — <current state>

### Next session context
- Memex is on: [branch] — [merged to main? yes/no]
- Worktrees still active: [list or "none"]

### Context health
- [one line from Step 8 — disciplined / patterns noticed / suggestions for next session]
```

Save to `~/Projects/personal/memex/Outputs/Session/session-close-[date].md` if non-trivial. Delete after the next session picks it up.
