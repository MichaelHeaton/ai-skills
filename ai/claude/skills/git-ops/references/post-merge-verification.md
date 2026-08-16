---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
---

# Post-merge issue verification

This is the post-merge backstop. `verify-closes.sh` also supports a `--pre-merge` mode, run automatically right after PR creation (see the non-negotiable callout near the top of `SKILL.md`) — it checks the same referenced issues against the PR's own `closingIssuesReferences` instead of issue state, catching a malformed multi-issue clause before merge instead of after.

After merging a PR whose `## Refs` section claims to close one or more issues, verify each one actually closed — GitHub's auto-close is silent on failure, so a malformed keyword (comma-list, typo'd number, wrong repo) leaves an issue open with no error anywhere.

**Preferred: run the script**, which does this for every referenced issue in one call instead of a hand-written loop:

```bash
bash ~/.claude/skills/git-ops/scripts/verify-closes.sh <pr-number> [owner/repo]
```

It parses the PR body for `Closes`/`Fixes`/`Resolves` references, checks each issue's state via `gh issue view`, and prints `CLOSED:<N>` / `OPEN:<N>` / `ERROR:<N>` per issue — exiting non-zero if any didn't close, so it's safe to gate a follow-up step on.

**Manual fallback**, if the script isn't available or you only need to check one issue:

```bash
gh issue view <N> --json state --jq .state
```

- **`CLOSED`** — matches the PR's claim, no action needed
- **`OPEN`** — the auto-close didn't fire; close it manually and note why (e.g. `gh issue close <N> --comment "Closed by #<PR>"`)

Either way, check every issue number listed in the merged PR's Refs section, not just the first — that's precisely the case that breaks silently (see git-ops's multi-issue closing rule). Skip this check only for PRs with no Refs/Closes section.
