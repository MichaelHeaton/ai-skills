---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: wrong-branch-commit-recovery
description: Recover when commits landed on the wrong branch — caught live by `branch-guard.py`'s MISMATCH block (see git-ops "Shared checkout branch-identity check") or discovered after the fact. Checks first whether the content already landed on `main` under a different branch/PR name before doing any recovery, then moves the commits to a correctly-named branch off `main`, opens/updates the right PR, verifies the content actually landed, and cleans up the wrong branch safely. Trigger on: "I committed to the wrong branch", "this branch is misnamed", "MISMATCH" advisory follow-up, "wrong branch, what do I do", "did this already land under a different name", or any request to move commits off a branch that doesn't match the ticket/prefix it should. Complements git-ops (which detects the mismatch) and post-merge-cleanup (whose squash-recovery verification pattern this skill reuses) — this is the recovery procedure itself, not a replacement for either.
---

# Wrong-Branch Commit Recovery

Commits landed on a branch that doesn't match its ticket ID or `feat`/`fix`/`docs` prefix — either `branch-guard.py` threw a `MISMATCH` advisory and it got missed or overridden, or the mismatch was only noticed after the fact. This skill is the actual recovery procedure. It assumes the detection already happened; for the detection mechanism itself, see git-ops' "Shared checkout branch-identity check" section — don't re-explain that here.

**Read git-ops in full before running this skill** if you haven't already this session — in particular "Branching," "Check PR history before force-deleting a branch name," and "Recovery recipe: merged branch + uncommitted new work on top." That last recipe is for a *different* case (uncommitted work sitting on a branch whose PR already merged) — don't confuse it with this one (committed work sitting on a branch with the wrong name/identity, PR not yet merged or not yet opened).

## Step 1 — confirm recovery is actually needed

**Before creating anything, rule out that this content already landed under a different name.** A duplicate PR for content that's already on `main` is worse than the original mismatch — it wastes review time and can produce a genuinely confusing merge conflict against itself.

```bash
# Does main already contain this content, landed via some other branch/PR?
git log main --oneline | grep -F "<distinctive commit message text from the wrong branch>"

# Patch-id comparison — survives a squash-merge rewrite, unlike the grep above
git cherry main <wrong-branch>
```

- `git cherry main <wrong-branch>` prints a `-` line for every commit whose patch-id is already reachable from `main` (already landed, under whatever branch/PR actually merged it) and a `+` line for every commit that is genuinely new.
- **All lines `-`** — the content already landed. Stop here. Do not create a new branch or PR. Delete the wrong branch per Step 4's safety check and note in your summary which PR actually carried the content.
- **Any lines `+`** — recovery is needed for those commits specifically. Continue to Step 2, moving only the `+`-prefixed commits.
- **No output at all** (branch has commits but `git cherry` finds nothing to compare, or the branch is empty relative to main) — re-run `git log main..<wrong-branch> --oneline` directly to see what's actually there before concluding anything; don't treat empty `git cherry` output alone as proof of either state.

If it's ambiguous which of several candidate branches might already carry this content, run `git cherry main <candidate>` against each rather than guessing from branch names alone.

## Step 2 — move the commits to a correctly-named branch

Only if Step 1 found genuinely new (`+`) commits.

**Create the new branch from current `main`, not from the wrong branch** — branching from the wrong branch would carry its identity (and any of its own accidental history) forward. Per git-ops "Branching," always cut from an up-to-date default branch:

```bash
git checkout main && git pull
git checkout -b <correctly-named-branch>
```

**Two ways to bring the commits over — pick based on how many there are and whether they're contiguous:**

1. **Cherry-pick each `+` commit individually** (preferred default):

   ```bash
   git cherry-pick <sha1> <sha2> ...
   ```

   More robust when the wrong branch has *any* commits mixed in that shouldn't move (e.g. an earlier commit that was correctly scoped, or noise from a shared checkout) — cherry-pick lets you select exactly the right SHAs instead of moving everything. Use the `+`-prefixed SHAs from `git cherry` in Step 1, oldest first, to preserve order.

2. **Reset-move** (only when every commit on the wrong branch belongs on the new branch, with nothing to leave behind):

   ```bash
   git branch <correctly-named-branch> <wrong-branch>   # if not already created above
   git checkout main
   ```

   This is just relabeling — the new branch pointer already carries the exact same commits as the wrong branch, no replay needed. Faster and avoids any cherry-pick conflict risk, but only safe when the wrong branch is 100% clean content (no stray commits, no commits already covered by Step 1's `-` lines).

   **If Step 1 found a mix of `-` and `+` commits, reset-move is not safe** — it would drag the already-landed `-` commits along too, which can produce spurious "no-op" diffs or duplicate-content review noise on the new PR. Fall back to cherry-pick in that case.

If a multi-commit rebase-style conflict shows up during cherry-pick (the same file touched by multiple commits on the branch, and by `main` since divergence), don't fight it commit-by-commit — see git-ops' "Multi-commit same-file rebase conflicts" and [references/rebase-conflicts.md](../git-ops/references/rebase-conflicts.md) for the fresh-branch-plus-net-diff approach, which applies here too.

**Push and open the PR:**

```bash
git push -u origin <correctly-named-branch>
gh pr create --repo <owner/repo> --head <correctly-named-branch> --title "..." --body "..."
```

Follow git-ops' PR description format and pre-flight checks (AGENT.md check, humanizer pass, `--repo`/`--head` flags) — this skill doesn't restate them.

**If a PR already exists under the wrong branch name** (e.g. `branch-guard` caught the mismatch after a PR was already opened), update that PR's head instead of opening a second one where it makes sense — or close it with a comment pointing at the new PR if GitHub won't let the head branch be renamed. Don't leave two open PRs pointed at the same content.

## Step 3 — verify the content actually landed as expected

**Don't trust an empty three-dot diff as proof of anything** — reuse the verification discipline from post-merge-cleanup's "Misnamed-branch recovery via squash" section rather than re-deriving it:

```bash
git cherry main <correctly-named-branch>
git diff main -- <specific-file-that-mattered>
```

- `git cherry` should now show every moved commit as `-` (already in `main`'s ancestry via the new branch — meaning nothing is missing relative to what Step 1/2 intended to move). If any still show `+`, the move is incomplete — go back to Step 2 before proceeding.
- The scoped `git diff` against the specific files the recovery was supposed to bring over confirms the *content* matches, not just that commit count lines up. A full-tree `git diff main...HEAD` is not a substitute — see post-merge-cleanup for why a squash or rewrite can make that read clean when content was actually dropped.

Only move to Step 4 once both checks are clean.

## Step 4 — clean up the wrong branch safely

**Do not force-delete the wrong branch without checking its PR history first** — per git-ops' "Check PR history before force-deleting a branch name":

```bash
gh pr list --head <wrong-branch> --state all
```

- **No PR ever existed for this branch** — safe to delete outright: `git branch -D <wrong-branch>` locally, `git push origin --delete <wrong-branch>` if it was pushed.
- **A PR exists (open)** — close it with a comment linking to the replacement PR before deleting the branch, so the history isn't silently orphaned. `gh pr close <n> --comment "Superseded by #<new-pr> — commits moved to the correctly-named branch, see wrong-branch-commit-recovery."`
- **A PR exists and is already merged/closed under this name** — this is the Step 1 "already landed" case; you should have caught it there. If you somehow reached Step 4 without having run Step 1 first, stop and go back — deleting a branch whose PR already merged real content, without confirming a replacement exists, risks losing the only reference to that history's origin.

Treat the branch name itself as reserved going forward, same as git-ops' general rule — don't reuse a deleted misnamed branch's name for unrelated future work.

## Relationship to other skills

- **git-ops** ("Shared checkout branch-identity check") is the detection mechanism — `branch-guard.py`'s `MISMATCH` block fires *before* a bad commit lands, when it's caught. This skill is what to do when that warning was missed, ignored, or the mismatch is only discovered after the fact (no live block to have caught it). Not a replacement for installing the guard — see ai-skills#689 for that.
- **post-merge-cleanup** owns the general pull/worktree/branch-delete/redeploy sequence after a normal merge. This skill's Step 3 verification pattern is borrowed directly from its "Misnamed-branch recovery via squash" section — read that section for the underlying rationale if `git cherry`'s patch-id behavior across a squash isn't already clear.
- **git-ops** "Recovery recipe: merged branch + uncommitted new work on top" solves a related but distinct problem: uncommitted work sitting on top of a branch whose PR *already merged*. This skill is for committed work sitting on a branch with the *wrong identity*, independent of merge state.
