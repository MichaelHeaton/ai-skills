---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: git-squash-conflict-recover
description: Recover when a branch was already squash-merged into main but new commits then landed on that same now-stale branch (e.g. a follow-up fix pushed before noticing the merge), causing a conflict or confusing diff on a new PR. Confirms what's already on main via the squash commit, isolates the stranded delta commit(s), cuts a fresh branch off updated main, cherry-picks or re-applies just the delta, opens a new PR, and safely deletes the stale branch only after confirming its content is captured elsewhere. Trigger on: "squash-merged branch has conflicts", "my branch is stale after a squash merge", "PR conflicts with itself after merge", "follow-up commit landed on an already-merged branch", or "how do I recover from this squash conflict". Prefers a fresh branch over `--force`/`--force-with-lease` on the old branch; force-with-lease is documented only as a fallback when keeping the same branch/PR is explicitly wanted. Related: #543, #549.
---

# Git Squash Conflict Recover

A branch was squash-merged into `main`, so its original commits are represented as one squash commit — but new commits then landed on that same now-stale local branch (a follow-up fix pushed before noticing the merge). Opening a new PR from it now produces a conflict or a confusing diff, because the base tree the follow-up commits were built on no longer matches `main`'s history. This skill is the recovery procedure: confirm the delta, move only the delta to a fresh branch, and retire the stale branch safely.

**Fresh branch is the default fix, not `--force`.** Per this repo's "never push directly to `main`" and no-force-push-without-explicit-instruction conventions, don't reach for `git push --force`/`--force-with-lease` on the old branch to paper over the conflict. Only use force-with-lease (Step 5) if the user explicitly wants to keep the same branch name/PR.

## Step 1 — confirm what's actually on `main`

Find the squash commit and see what it actually carried:

```bash
git log main --oneline | head -20
git show <squash-sha> --stat
```

This is the baseline — anything already inside that squash commit is *not* part of the delta you need to move, no matter how it looks in `git log <stale-branch>`.

## Step 2 — identify the stranded delta

The stale branch still has its full pre-squash history plus whatever landed after the merge. Find just the commits `main` doesn't have:

```bash
git fetch origin main
git log main..<stale-branch> --oneline
```

- Commits that predate the squash-merge and are already represented in `<squash-sha>` will usually **not** appear here (they're ancestors `main` already contains via the squash, once `main` is up to date) — if they do appear, it means `main` was fetched stale or the squash didn't fully capture them; re-verify against Step 1 before proceeding.
- What's left is the real delta — typically just the follow-up commit(s) made *after* the squash-merge landed. These are the only commits worth carrying forward.

If it's unclear whether a commit's content already made it into the squash, compare its patch directly against the squash commit's diff (`git show <squash-sha> -- <file>` vs. `git show <candidate-sha> -- <file>`) rather than guessing from commit messages alone.

## Step 3 — cut a fresh branch off updated `main`

```bash
git checkout main && git pull
git checkout -b <new-branch-name>
```

Branching from the stale branch would carry its now-divergent base tree forward and reproduce the same conflict. Always cut fresh from `main`, per git-ops' branching convention.

## Step 4 — bring over just the delta

```bash
git cherry-pick <delta-sha1> <delta-sha2> ...
```

Use the delta SHAs identified in Step 2, oldest first. **Expect cherry-pick to conflict even on a change that applied cleanly before** — the base tree is different now that the squash rewrote history, so a clean pre-squash apply is no guarantee here. If cherry-pick conflicts:

- Resolve file-by-file as usual, or
- For a small, well-understood delta, re-apply the changed files manually instead of fighting the cherry-pick (check out just the specific paths from the stale branch's tip and stage them) — faster when the delta is one or two files and the conflict is purely structural (base tree mismatch), not a real content collision.

Push and open the PR:

```bash
git push -u origin <new-branch-name>
gh pr create --repo <owner/repo> --head <new-branch-name> --title "..." --body "..."
```

Follow git-ops' PR description format and pre-flight checks — this skill doesn't restate them.

## Step 5 — alternative: force-with-lease on the same branch (only if explicitly requested)

If the user explicitly wants to keep the same branch name and existing PR rather than open a new one, `--force-with-lease` on the stale branch after rebasing it onto `main` is a documented alternative:

```bash
git checkout <stale-branch>
git rebase main
git push --force-with-lease
```

This is riskier than the fresh-branch approach (rewrites shared history on a branch others may have pulled, and the rebase is exposed to the same base-tree-mismatch conflicts as Step 4's cherry-pick) — use it only on explicit instruction, never as the default.

## Step 6 — verify before deleting the stale branch

**Never force-delete the stale branch blind.** Confirm its content is either on `main` already or captured in the new branch:

```bash
git cherry main <new-branch-name>
git cherry main <stale-branch>
```

Both should show every commit as `-` (already reachable from `main`'s ancestry, whether via the original squash or the new branch's merge). If `<stale-branch>` still shows `+` lines after the new PR merges, something didn't make it over — go back to Step 2 before deleting anything.

Once clean:

```bash
git branch -D <stale-branch>
git push origin --delete <stale-branch>   # if it was pushed
```

If a PR still exists open against the stale branch, close it with a comment pointing at the replacement PR before deleting — don't leave two open PRs pointed at overlapping content.

## Relationship to other skills

- **post-merge-cleanup** owns the routine pull/worktree/branch-delete/redeploy sequence after a normal merge, and its squash-recovery verification pattern (`git cherry` against a squash commit) is what Step 1/6 above reuse — read it for the underlying rationale if that isn't already familiar.
- **wrong-branch-commit-recovery** solves a related but distinct problem: commits on a branch with the *wrong identity* (misnamed relative to its ticket/prefix), independent of merge state. This skill is for a branch with the *right* identity that's simply stale relative to a squash-merge that already happened.
- Further reading on this scenario's origin: #543, #549.
