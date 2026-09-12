---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: merge-collision-recovery
description: Detect and repair the "fix-up commit raced a squash-merge and lost" pattern — a follow-up commit meant for an in-flight PR never landed because someone else squash-merged that PR first, so the squash commit on main looks complete but silently lacks the fix-up's content. Diffs origin/main's squashed file against what the fix-up intended, confirms the race via commit timing plus ruling out a legitimate later edit (not a SHA-ancestor check, which can't distinguish this case since squashing always changes the SHA), and drafts a corrective follow-up PR. Use when asked "did my fix-up make it into the squash merge", "why is this file missing changes I pushed", "the PR merged but my follow-up commit isn't in main", "confirm whether this commit landed", or "check for a lost fix-up race". Narrower than git-squash-conflict-recover (a session's own commits stranded after squash-merging its own branch) — this covers someone else's squash-merge racing ahead, with nothing on the surface signaling loss.
compatibility: Requires git CLI access to the repo and origin remote; gh CLI (or equivalent) to open the corrective PR.
---

# Merge Collision Recovery

A fix-up commit was meant to land on top of an in-flight PR before it merged. Instead, someone (a teammate, a concurrent session, a fast auto-merge) squash-merged that PR first — so the fix-up commit raced the squash and lost. The squash commit on `main` looks complete and normal; nothing about it signals that content is missing. The fix-up commit may still exist somewhere (a local branch, a stash, a background agent's worktree), but it never made it into `main`.

This is a **race-condition diagnosis skill**, not a general merge-conflict skill. It answers one question: did this specific fix-up actually land, and if not, how do we get its content into `main` now.

**See also**: `git-squash-conflict-recover` covers a different shape — a session's *own* follow-up commits stranded after it squash-merged its own branch (it already knows those commits exist and are missing). This skill covers the case where the squash-merge was done by someone else, and the loss is not yet confirmed — start here whenever you're not sure the fix-up made it in at all.

## 1. Detection — compare squash content against intended content

Don't diff against the pre-squash branch tip — that always looks fine locally and tells you nothing about what actually landed on `main`. Diff the **squash commit's version of the file on `origin/main`** against what the fix-up commit was supposed to add:

```bash
git fetch origin
git show <squash-sha>:<path/to/file> > /tmp/landed.txt
git show <fixup-sha>:<path/to/file> > /tmp/intended.txt
diff /tmp/landed.txt /tmp/intended.txt
```

A non-empty diff means the squash commit's content disagrees with what the fix-up intended — proceed to confirm the cause in step 2 rather than assuming it's this race (drift can also come from a legitimate later edit).

## 2. Confirm the fix-up really didn't land

**Don't check SHA ancestry — it can't answer this question.** Squashing always creates a brand-new commit; the fix-up's original SHA is *never* an ancestor of a squash commit regardless of whether its content actually made it in. `git branch --contains <fixup-sha>` and `git log --oneline <squash-sha> | grep <fixup-sha>` will both come back empty in every real case, including one where the content landed fine (folded into the squash by whoever merged it) — so neither can distinguish "raced and lost" from "already there under a different SHA."

Use timing and content instead:

1. **Was the fix-up committed before the squash-merge happened?** Compare the fix-up commit's timestamp against the squash merge's actual merge time:

   ```bash
   git show <fixup-sha> --format=%cI -s
   gh pr view <original-pr> --json mergedAt -q .mergedAt
   ```

   If the fix-up's commit time is *before* `mergedAt`, it existed in time to have been included — if step 1's diff still shows it's missing, that's real evidence of a race, not just a timing coincidence.

2. **Check for a later commit on the same file** — not because it could explain step 1's diff (that diff is pinned to the squash commit's own tree at merge time, so nothing committed afterward can affect it), but as a safety check before recovering in step 3: a later commit on the same file could be legitimate follow-on work that step 3's recovery would otherwise clobber if applied blindly.

   ```bash
   git log --oneline --since="<mergedAt>" -- <path/to/file>
   git fetch origin main   # make sure this is checked against origin/main, not a stale local branch
   ```

   If nothing shows up, proceed to step 3 — recovering the fix-up's content won't step on anything else. If a later commit does show up, inspect it first (`git show <that-sha> -- <path/to/file>`) and reconcile it with the fix-up's content in step 3's recovery rather than overwriting it.

**Known out-of-scope cases**: this skill assumes the fix-up was genuinely dropped by a squash-merge race. Two cases outside that scope won't be distinguished by the checks above: (1) the fix-up's content was deliberately excluded or reworked during PR review, not raced away — timing alone can look identical; (2) the fix-up's commit time is *after* `mergedAt`, meaning it was never in a position to race in the first place. Either case still routes through step 3's corrective PR, which gets human review before merging — so a misdiagnosis here costs an unnecessary PR, not a silent bad merge.

## 3. Recovery — land the missing content on a fresh branch

```bash
git checkout main
git pull origin main
git checkout -b fix/recover-<short-description>-<ticket>
```

**If the fix-up commit is still a reachable ref** (local branch, stash, another worktree), cherry-pick it directly:

```bash
git cherry-pick <fixup-sha>
```

**If it's no longer reachable**, manually recreate the diff captured in step 1 (`/tmp/intended.txt` minus `/tmp/landed.txt`) against the current file on `main`, since a straight cherry-pick has nothing to replay from.

Open the corrective PR referencing both the original PR and the root-cause ticket:

```bash
gh pr create --title "fix: recover fix-up content lost to squash-merge race" \
  --body "The fix-up in <fixup-sha> raced PR #<original-pr> and lost — <squash-sha> was cut before the fix-up landed. Re-applies the missing content. Refs #<ticket>"
```

## 4. After recovery

Re-run the step 1 diff against the new PR's branch tip (not `origin/main` again until it merges) to confirm the recovered content now matches what was originally intended, before asking for review.
