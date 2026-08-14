---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: post-merge-cleanup
description: Clean up after a PR merges — pull main, remove the worktree, delete the local (and remote-if-needed) feature branch, and run the repo's redeploy/build step — without requiring a full session-close run. Use whenever the user says "that PR merged", "merged, can you clean up", "PR's in, sync main", or right after confirming a merge via gh/glab, in any repo. For end-of-session hygiene across multiple repos, use session-close instead — this skill is the single-repo, single-PR version of the same sequence.
compatibility: Requires git; gh or glab for remote branch state.
---

# Post-Merge Cleanup

The four-step sequence every merged PR needs, as a skill instead of prose duplicated per-repo in CLAUDE.md files. Portable — nothing here assumes `make install-system` or any other ai-skills-specific tooling.

## 1. Pull main (fast-forward)

```bash
git -C <repo> checkout main && git -C <repo> pull origin main
```

If the pull isn't a clean fast-forward, stop and surface it — that means main diverged in a way this cleanup shouldn't silently resolve.

## 2. Remove the worktree (if one was used)

```bash
git -C <repo> worktree list
```

If the merged branch had its own worktree, remove it:

```bash
git -C <repo> worktree remove <worktree-path>
```

Skip this step entirely if the work happened in the main checkout — not every merge involves a worktree.

## 3. Delete the local (and remote, if needed) branch

```bash
git -C <repo> branch -d <branch-name>
```

`-d` only deletes fully-merged branches — if it refuses on a squash-merged branch (common; the squash commit's hash differs from the branch's original commits even though the content landed), verify the content actually landed before falling back to `-D`:

```bash
git -C <repo> log main --oneline | grep -F "<distinctive commit message text>"
```

**Remote branch**: skip deletion if GitHub/GitLab already auto-deleted it (check `gh pr view <n> --json headRepositoryOwner,headRefName` or the merge response) — don't assume it needs manual cleanup.

## 4. Redeploy / rebuild (repo-appropriate)

This step is intentionally not hardcoded to any one command. Detect what the repo actually uses:

- `Makefile` with an `install`/`deploy`/`build` target → run it
- `package.json` with a `build`/`deploy` script → run it
- No such step documented → skip silently, nothing to redeploy

If unsure which command applies, ask once rather than guessing at a destructive or long-running build step.

## Report

```
✓ main synced (fast-forward)
✓ worktree removed
✓ local branch deleted (remote already auto-deleted)
✓ redeployed via `make install-system`
```
