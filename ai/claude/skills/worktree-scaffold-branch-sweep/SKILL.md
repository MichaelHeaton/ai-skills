---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: worktree-scaffold-branch-sweep
description: Opt-in, explicitly-invoked sweep of stray worktree-agent-* scaffold branches (or an equivalent scaffold-naming pattern) that accumulate across sessions in a repo with heavy worktree-based agent usage. Finds local branches matching the scaffold pattern, verifies each is a merged ancestor of main via git merge-base --is-ancestor before proposing deletion, surfaces a count and full list for confirmation, then deletes only the confirmed, already-merged branches with git branch -d. This is cross-session backlog cleanup, NOT wired into session-close's automatic per-session flow — session-close's own Step 5 deliberately scopes cleanup to branches worked in the current session and leaves this backlog untouched by design. Trigger only on explicit requests: "sweep worktree scaffold branches", "clean up worktree-agent branches", "run the scaffold branch sweep", "sweep stray scaffold branches", "clean up the worktree branch backlog". Never auto-invoke from session-close or any other skill's automatic flow.
compatibility: Requires git. Assumes a local clone with the repo's default branch reachable as `main` (adjust references to `master` if that's the repo's default).
---

# Worktree Scaffold Branch Sweep

Batch cleanup for the backlog of stray `worktree-agent-*` scaffold branches that accumulate over many sessions of worktree-isolated agent work. This is deliberately **opt-in and explicitly invoked** — it is never wired into `session-close`'s automatic per-session flow.

## Why this exists, and why it isn't automatic

`session-close`'s Step 5 already prunes dead worktrees and deletes local branches whose remote tracking ref is gone — but it scopes that cleanup to branches worked in *this session* (matched against `git config user.email` and this session's own activity). It deliberately leaves scaffold branches from other authors and older sessions untouched, because they're outside that session's scope, not because they're safe to ignore forever. Nothing else sweeps that backlog on any cadence, so it just grows.

`dev-team`'s `dev-team-coder` role (see `ai/claude/skills/dev-team/SKILL.md`, Step 2, "Clean up the stray scaffold branch the rename leaves behind") already documents the safety check for deleting *one* of these branches individually, after a worktree rename leaves the auto-generated name behind:

```bash
git merge-base --is-ancestor <worktree-agent-branch> main && echo safe-to-delete
```

This skill generalizes that single-branch check into a batch sweep across the whole backlog, run on demand rather than as a side effect of any other skill's flow.

## Step 1 — Confirm this is an explicit, standalone invocation

**Do not run this as part of `session-close`, `dev-team`, or any other skill's automatic sequence.** If you arrived here from another skill's flow rather than a direct user request to sweep scaffold branches, stop and confirm with the user first — this skill's whole reason for existing is that scaffold-branch cleanup is cross-session debt that needs a deliberate, separately-invoked pass, not an automatic one.

## Step 2 — Find candidate scaffold branches

List local branches matching the scaffold-naming pattern:

```bash
git branch --list 'worktree-agent-*'
```

`worktree-agent-*` is the pattern this skill defaults to, matching the naming used by this repo's own worktree-isolated agent tooling (see `dev-team-coder`'s scaffold branches). If a different isolation tool in use here names its scaffold branches differently, adjust the glob accordingly — e.g. `git branch --list '<other-prefix>-*'` — and note the pattern used in your summary so it's clear what was and wasn't swept.

If no branches match, report that and stop — there's nothing to sweep.

## Step 3 — Verify each candidate is a merged ancestor of main

**Never delete on name pattern alone.** For every branch found in Step 2, check whether it is actually a merged ancestor of `main`:

```bash
git fetch origin main --quiet 2>/dev/null
for b in $(git branch --list 'worktree-agent-*' --format='%(refname:short)'); do
  if git merge-base --is-ancestor "$b" main; then
    echo "ELIGIBLE: $b"
  else
    echo "SKIP (not an ancestor of main): $b"
  fi
done
```

- **`ELIGIBLE`** means the branch's content is already fully reachable from `main` — safe to delete.
- **`SKIP`** means the branch has commits not on `main` (still in progress, abandoned mid-work, or squash-merged under a different hash — see the note below). Leave these alone regardless of how old or how scaffold-like the name looks.

**Squash-merge caveat.** A squash-merged branch can legitimately fail the ancestor check even though its content already landed on `main`, because the squash commit has a different hash than anything on the branch. This skill does not attempt the deeper `git cherry`/content-diff verification `session-close` uses for that case ([references/merged-branch-push-safety.md](../session-close/references/merged-branch-push-safety.md) in that skill) — a `SKIP` here is a conservative default, not a final verdict. If a specific `SKIP`'d branch is suspected to be squash-merged, investigate it manually before deciding, or leave it for a future pass.

## Step 4 — Surface count and list, require confirmation

Mirror `session-close` Step 5's exact batch-confirmation pattern for its local-branch cleanup (see `ai/claude/skills/session-close/SKILL.md`, Step 5, "When more than 3 branches would be deleted, show the list and ask..."). Apply the same pattern here regardless of count — this sweep has no automatic path, so every run asks:

> **Delete these `N` merged scaffold branches in `<repo-name>`?**
>
> - **Yes, delete all** — run the cleanup now
> - **Let me pick** — list each branch for individual confirmation
> - **Skip** — leave scaffold branches as-is

List every `ELIGIBLE` branch by name alongside the count. If `SKIP`'d branches exist, list those separately too, so the user can see what was found but excluded and why (not an ancestor of `main`).

Do not proceed to Step 5 without an explicit "yes" (or per-branch confirmations under "let me pick").

## Step 5 — Delete confirmed branches

Delete only the branches confirmed in Step 4, using the safe delete flag — never `-D` — since ancestor-of-`main` status was already confirmed in Step 3:

```bash
git branch -d <branch>
```

`-d` refuses to delete a branch git doesn't recognize as fully merged, so this is a second, mechanical safety net on top of Step 3's explicit check, not a substitute for it. If `-d` unexpectedly refuses a branch that Step 3 marked `ELIGIBLE`, stop and investigate rather than escalating to `-D` — that mismatch means something about Step 3's check or the branch state has changed since.

Report which branches were deleted and which were left alone (and why), in the same summary.

## Test plan

Verify against a repo with a known mix of merged and unmerged `worktree-agent-*` branches:

1. Create a throwaway repo (or a disposable worktree/branch set in a real one) with several `worktree-agent-*` branches: some fully merged into `main`, some with unmerged commits still ahead of `main`.
2. Run Step 2 and confirm all scaffold branches are listed as candidates, merged and unmerged alike.
3. Run Step 3 and confirm only the merged branches are marked `ELIGIBLE`; unmerged ones are marked `SKIP`.
4. Run Step 4 and confirm the confirmation prompt lists the correct count and names, matching only the `ELIGIBLE` set.
5. Confirm deletion and verify only the `ELIGIBLE` branches are gone afterward (`git branch --list 'worktree-agent-*'`) — the `SKIP`'d branches must still exist.
6. Re-run the sweep once more against the now-clean set and confirm it correctly reports nothing to sweep.

## Related skills

- **`session-close`** — Step 5 prunes dead worktrees and deletes local branches from *this session's own work* (matched against `git config user.email` and this session's activity). It deliberately does not touch the cross-session scaffold-branch backlog this skill targets; the two are complementary, not overlapping. Its batch-confirmation UX for >3 branches is the exact pattern mirrored in Step 4 above.
- **`dev-team`** — `dev-team-coder`'s Step 2 documents the single-branch version of this skill's Step 3 safety check, applied inline right after a worktree rename leaves a stray scaffold branch behind. This skill generalizes that same check into a standalone, batch, cross-session sweep.
- **`git-ops`** — general branching and PR conventions; not scaffold-branch-specific, but the underlying git hygiene rules this skill operates within.

## Scope boundaries

- Only local branches are considered — this skill does not touch remote branches or open PRs.
- Only branches matching the configured scaffold pattern are candidates — it will never delete a branch just because it looks stale or old; name match is the entry condition, ancestor-of-`main` is the deletion condition, and both are required.
- This skill makes no changes to `session-close`, `dev-team`, or any other skill's own flow. It exists purely as a separately-invoked pass.
