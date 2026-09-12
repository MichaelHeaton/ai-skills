---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: concurrent-edit-recovery
description: Recover a local edit that vanished or reverted in a shared (non-worktree) checkout — usually a concurrent session's stash swallowing your in-progress changes. Walks git reflog and git stash list to find the content, distinguishes an orphaned stash from a genuinely lost/unreachable commit (git show / git branch --contains), then re-authors it in a fresh worktree off latest main and opens a PR — never back into the shared checkout that caused the collision. Covers stash disposition: keep the original as a backup until the recovery merges, then drop it. Distinct from iac-recover (Terraform state/provider drift) — this is for lost git content. Trigger on "my changes disappeared", "a file I was editing reverted", "did another session stash my work", "recover lost edit", "find my dropped stash", "is this commit actually lost", or suspicion a concurrent Claude session touched the same shared checkout.
compatibility: Requires git. Assumes a shared (non-worktree) checkout was involved — see git-ops for the underlying concurrent-session detection this skill reacts to after the fact.
---

# Concurrent Edit Recovery

A file you were editing looks reverted or missing in a shared (non-worktree) checkout. This is usually not data loss — it's a concurrent session sharing the same working directory that stashed, checked out, or reset over your in-progress work. This skill finds it and gets it safely into a PR.

Cross-reference: git-ops's "Shared checkout branch-identity check" and "Live concurrent-session detection" sections cover *detecting* a concurrent session while it's happening. This skill picks up after the fact, once content already appears to have vanished.

## 1. Diagnose — find what happened

Start with the reflog, then check for a stash created around the same time:

```bash
git reflog --date=iso | head -30
git stash list --format='%H %gd %gs %ci'
```

Look for a `stash` or `checkout`/`reset` event near the time your edit disappeared. A concurrent session sharing this checkout is the most common cause — cross-reference git-ops's shared-checkout and live-concurrent-session detection sections rather than re-diagnosing that here.

## 2. Distinguish an orphaned stash from a lost commit

These need different recovery paths — confirm which one you have before proceeding.

**Orphaned stash** — content sits in `git stash list`, still fully recoverable:

```bash
git stash show -p stash@{N}
```

**Lost/unreachable commit** — content was committed, then the branch got reset or force-pushed away. Locate the commit via reflog, inspect it, then confirm it's genuinely unreachable from any current branch before treating it as lost:

```bash
git show <sha>
git branch --all --contains <sha>
```

If `--contains` lists a branch, the commit isn't actually lost — check that branch out normally instead of running a recovery. Only treat it as a true recovery case when `--contains` comes back empty.

## 3. Recover into a fresh worktree

**⚠️ Never recover directly into the shared checkout that caused the collision** — that's the same checkout a concurrent session may still be using, and recovering there risks the exact same collision again.

1. Create an isolated worktree off latest `main`:

   ```bash
   git fetch origin main
   git worktree add ../recover-<short-desc> origin/main
   ```

2. Re-author the content there — apply the stash diff, or cherry-pick the found commit:

   ```bash
   # orphaned stash
   git -C ../recover-<short-desc> stash apply <stash-sha>

   # lost commit
   git -C ../recover-<short-desc> cherry-pick <sha>
   ```

   **If this conflicts** (the worktree's `main` has moved on since the stash/commit was made — realistic given this is exactly the kind of drift a concurrent-session collision produces): resolve the conflicting hunks by hand, `git add` the resolved files, then `git cherry-pick --continue` (or, for a stash apply conflict, resolve and `git stash drop <stash-sha>` only after confirming the resolved content is correct — never abandon mid-conflict without either finishing or explicitly `--abort`ing). Don't force the stash/commit's exact old content over a legitimate intervening change — reconcile the two.

3. Commit, push, and open a PR through the normal git-ops flow (branch naming, commit message format, PR description).

## 4. Stash disposition — when to drop, when to keep

**Leave the original stash in place as an informational backup** until the recovered content is confirmed merged through its PR. Do not drop it speculatively before recovery is verified — this repo's convention is to always identify a stash entry precisely (by SHA, not just index) before touching it; see git-ops for the full stash-safety rule.

Once the PR merges and you've confirmed the recovered content matches what was in the stash, it's safe to drop:

```bash
git stash list --format='%H %gd %gs'   # re-find the entry's CURRENT stash@{n} by its SHA — the index shifts
git stash drop <current stash@{n}>     # `drop` only accepts stash@{n}, not a bare commit SHA — apply does, drop doesn't
```

If the PR review changes the content (edits during review, conflicts resolved differently), keep the original stash a while longer as a reference for what the pre-recovery state actually was.
