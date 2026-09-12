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

**⚠️ Every commit on the stale branch will show up here, including the pre-squash ones — that's expected, not a sign something went wrong.** Squashing rewrites history: the squash commit's SHA is new and its individual pre-squash commits are never its ancestors, so `git log main..<stale-branch>` will *always* list the full pre-squash history plus anything added after, no matter how up to date `main` is. Don't treat their appearance as "main wasn't fetched" or "the squash didn't capture them" — expect the full list and use content comparison, not presence in this log, to sort out which commits are the real delta.

```bash
git fetch origin main
git log main..<stale-branch> --oneline
```

To find the real delta among everything this lists:

- **Commit timing is the fastest first filter, not proof on its own**: anything authored/committed *before* the squash-merge landed is presumptively already inside `<squash-sha>`; anything *after* is presumptively the real delta. Cross-check with `git show <squash-sha> --format=%cI -s` for the squash's own commit time.
- **Confirm with content, don't stop at timing** — for each candidate delta commit, compare its patch against the squash commit's diff for the same file(s):

  ```bash
  git show <squash-sha> -- <file>
  git show <candidate-sha> -- <file>
  ```

  If the candidate's changes are already present in the squash commit's diff, it's not real delta — drop it. What's left after this filter is the actual delta worth carrying forward, typically just the follow-up commit(s) made after the merge.

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

**Never force-delete the stale branch blind.** `git cherry` is the wrong tool here — it compares patch-IDs by commit, and a squash commit's combined diff never patch-matches its individual pre-squash commits, so it will show `+` (unmerged) for the stale branch's own history *permanently*, whether or not anything is actually missing from `main`. Use a content diff instead, which doesn't care about commit-graph shape:

```bash
git fetch origin main
git diff main <stale-branch> -- <files the stale branch actually touches>
```

**Scope the diff to the stale branch's own files, not a whole-tree diff.** An unscoped `git diff main <stale-branch>` also picks up unrelated commits that landed on `main` from other work after the stale branch was cut — those show up as non-empty diff output that has nothing to do with whether *this* branch's content made it over, producing a false "not safe yet" reading. Scoping to the touched files avoids that false alarm.

An empty (scoped) diff means every line of content unique to the stale branch is already present in `main` (via the original squash plus the new PR's merge) — safe to delete. Any remaining diff output means real content hasn't landed yet — go back to Step 2 and re-check the delta before deleting anything.

Once clean:

```bash
git branch -D <stale-branch>
git push origin --delete <stale-branch>   # if it was pushed
```

If a PR still exists open against the stale branch, close it with a comment pointing at the replacement PR before deleting — don't leave two open PRs pointed at overlapping content.

## Relationship to other skills

- **post-merge-cleanup** owns the routine pull/worktree/branch-delete/redeploy sequence after a normal merge, including its own squash-merge branch-deletion fallback (`git branch -d` refusing on a squash-merged branch, verified instead via commit-message search) — this skill's Step 6 content-diff check is a more general version of that same "confirm the content actually landed before deleting" discipline.
- **wrong-branch-commit-recovery** solves a related but distinct problem: commits on a branch with the *wrong identity* (misnamed relative to its ticket/prefix), independent of merge state. This skill is for a branch with the *right* identity that's simply stale relative to a squash-merge that already happened.
- Further reading on this scenario's origin: #543, #549.
