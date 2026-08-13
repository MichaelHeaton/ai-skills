---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Merged-branch push safety (Steps 3–5 detail)

Narrow edge cases that show up when pushing worktree/branch commits or cleaning up local branches — the `AHEAD_BRANCHES` count from Step 1 is only a point-in-time snapshot, so don't skip these checks just because Step 1 flagged a branch as ahead.

## Before pushing a worktree or non-main branch (Steps 3 and 4)

Check merged-PR state before pushing, per git-ops's "Before pushing to an existing branch" rule:

```bash
GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}") \
  gh pr list --head <branch> --state merged --json number,title
```

- **Non-empty result** — the PR is already merged. Do not push this branch. Follow git-ops's merged-branch recovery: check out `main`, pull, create a fresh branch, re-apply any genuinely new content (verify with `git diff origin/main..HEAD -- <file>` — two-dot, not three-dot — since a three-dot diffstat can misrepresent already-merged content after a squash-merge), then push that new branch and go straight to branch cleanup for the stale one.
- **Empty result** — push normally:

  ```bash
  # GitHub SSH remotes:
  bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh <worktree-path> push -u origin <branch>
  # HTTPS remotes or other hosts:
  git -C <worktree-path> push -u origin <branch>
  ```

- After pushing, confirm the branch actually landed on the remote — this is a post-push confirmation, not a substitute for the merged-PR check above:

  ```bash
  git ls-remote --heads origin <branch>
  ```

  If the output is empty, the push didn't take. Retry it before proceeding. If the retry fails, stop and surface the error — do not attempt PR creation against a missing branch.

## Squash-merged local branches (Step 5)

The `-d` flag only deletes fully-merged branches — unmerged ones are left alone. **A squash-merged branch is the far more common cause of "not fully merged" here**, not just a force-deleted remote: the branch's commits genuinely landed on `main`, but git doesn't recognize them as ancestors because the squash commit has a different hash. Before falling back to `-D`, verify the content actually landed rather than assuming:

```bash
gh pr view <branch> --json state,mergedAt   # only works while the remote branch still exists
git log --oneline --all --grep="<commit-subject>"
git cherry main <branch>                    # empty output = every commit is already in main
```

**`git cherry` is not itself infallible after a squash-merge** — it has been observed reporting a genuinely-landed commit as `+` (not yet applied), likely when the squash commit's diff doesn't patch-match cleanly against the original commits' combined diff. Don't trust `git cherry`'s +/- alone in either direction — cross-check with a direct content diff before treating any of the three checks above as the final word:

```bash
git diff main..<branch>   # two-dot: does the branch's actual content differ from main's current tip?
```

- **Empty** — the branch's content is already fully present on `main`, regardless of what `git cherry` or the commit-message grep showed. Safe to `-D`.
- **Non-empty** — real pending content exists. Do not force-delete, even if `gh pr view` or `git cherry` suggested the branch was already captured.

Only use `-D` once the content diff confirms the work is captured elsewhere — for a genuinely force-deleted, unmerged remote, the diff will show real differences.
