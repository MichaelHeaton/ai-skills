---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# Before pushing to an existing branch

Before every `git push` to a feature branch, check whether its PR is already merged:

```bash
export GH_TOKEN=$(gh auth token --user "${GH_PERSONAL_USER}")
gh pr list --head <branch-name> --state merged --json number,title
```

- **Empty result (`[]`)** — PR is open or doesn't exist yet. Push normally.
- **Non-empty result** — PR is already merged. Do not push. Instead:
  1. Checkout the default branch and pull: `git checkout main && git pull`
  2. Create a new branch: `git checkout -b <descriptive-name>`
  3. Apply the pending changes (cherry-pick or re-apply)
  4. Push the new branch and open a new PR

Pushing to a merged branch orphans commits — they won't be in the default branch and require a cherry-pick recovery.

**A three-dot diffstat is not reliable evidence of pending work after a squash-merge.** `git diff origin/main...HEAD --stat` uses the merge-base at the point the branch diverged — but a squash-merge rewrites history and breaks that lineage, so the diffstat can show insertions/deletions that are already merged. Don't trust a non-empty `--stat` alone to mean "there's real pending work here." Verify with direct content comparison instead:

```bash
git diff origin/main..HEAD -- <file>   # two-dot: current tip vs current tip, not a stale merge-base
```

If that returns empty for every file the three-dot diffstat flagged, the branch's content is already merged — treat it the same as the "non-empty merged-PR check" case above, not as work to push.

## CI/CD behavior when pushing to an open PR

In repos where CI runs `plan` on PR push and `apply` on merge to main:

- Pushing to an open PR re-runs the **plan** check only — it does **not** trigger apply
- Apply only fires when the PR is **merged** to the default branch
- Never say "CI will re-run" in a way that implies apply will re-run — only the plan re-runs
