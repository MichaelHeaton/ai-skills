---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# Post-merge issue verification

After merging a PR whose `## Refs` section claims to close one or more issues, verify each one actually closed — GitHub's auto-close is silent on failure, so a malformed keyword (comma-list, typo'd number, wrong repo) leaves an issue open with no error anywhere:

```bash
gh issue view <N> --json state --jq .state
```

- **`CLOSED`** — matches the PR's claim, no action needed
- **`OPEN`** — the auto-close didn't fire; close it manually and note why (e.g. `gh issue close <N> --comment "Closed by #<PR>"`)

Run this for every issue number listed in the merged PR's Refs section, not just the first — that's precisely the case that breaks silently (see git-ops's multi-issue closing rule). Skip this check only for PRs with no Refs/Closes section.
