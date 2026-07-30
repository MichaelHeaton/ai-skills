---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# Multi-repo operations

When committing, pushing, or creating PRs across more than one repo in the same session, **run one Bash call per repo** — never batch cross-repo git operations as parallel tool calls.

**Why:** Parallel Bash calls share working directory state. A `cd` in one parallel call can leak into another, landing commits or PRs in the wrong repo or branch. Recovery requires rescue branches, hard resets, and re-runs — all avoidable.

```bash
# Safe — one call per repo, each with explicit cd
cd /path/to/repo-a && git add . && git commit -m "..."
# then separately:
cd /path/to/repo-b && git add . && git commit -m "..."

# Risky — parallel calls where CWD from one may bleed into another
# [never batch cross-repo git work in parallel]
```

This applies to: `git add`, `git commit`, `git push`, `gh pr create`, and any command whose behavior depends on CWD being a specific repo.
