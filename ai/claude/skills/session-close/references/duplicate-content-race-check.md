---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
---

# Duplicate-content race check (fix-up commit racing a squash-merge)

A distinct collision shape from the other two references in this skill: [concurrent-session-check.md](concurrent-session-check.md) detects a live process or unexpected `origin` movement, and [merged-branch-push-safety.md](merged-branch-push-safety.md) covers pushing to a branch whose PR already merged. Neither covers a pure **timing gap** — a fix-up commit that needed to land before a squash-merge, but didn't get there in time.

**The shape**: a background capture agent's `git add`/`git commit` in a shared, non-worktree checkout sweeps unrelated edits into an already-open PR branch (often a leftover branch from an earlier same-day session). That PR squash-merges before a fix-up commit can land, so the squash captures the still-bundled, not-yet-corrected state. A second, independently-clean PR for the same content then merges shortly after — and `main` ends up with the content duplicated across two commits, neither of which was wrong in isolation.

## (a) Pre-commit scope check for background/capture agents

Before any background or capture agent runs `git add` / `git commit` on behalf of the session in a shared, non-worktree checkout, verify the staged file set matches only what it was actually asked to touch:

```bash
git -C <repo> diff --cached --name-only
```

Compare that list against the task's actual scope (the files the ticket or task instructions named). A file outside that scope — especially one already touched by an in-flight PR on a leftover branch — is the signal that a sweep-and-commit is about to bundle unrelated content into someone else's open PR. Unstage it before committing:

```bash
git -C <repo> restore --staged <file>
```

This is a cheap check at commit time, not a guarantee — it only prevents *this* agent from causing the collision. It does nothing about a squash-merge that lands in the gap after a legitimately-scoped commit but before a needed fix-up reaches the same branch; that's what (b) below is for.

## (b) Post-hoc check when two same-file PRs merge close together

Run this whenever Step 9 or Step 10 notices two PRs touching the same file merged within a short window of each other (same day, same session, or surfaced by a later session's own same-day search) — that proximity alone is worth a look, even when both PRs individually looked clean:

```bash
git -C <repo> log --oneline --all -- <file>   # recent commits/merges touching this file
git -C <repo> show <merge-commit-1>:<file> > /tmp/v1
git -C <repo> show <merge-commit-2>:<file> > /tmp/v2
diff /tmp/v1 /tmp/v2
```

Then check the file's current state on `main` for a duplicated section or block — content that appears twice, once from each merge, rather than the two merges having cleanly built on each other:

```bash
git -C <repo> show origin/main:<file> | grep -c "<distinctive line from the content in question>"
```

A count greater than the number of times that content should legitimately appear is the race signature. This is content cleanup, not blame — neither original PR was wrong on its own, only their timing collided. Fix by opening a small follow-up PR that removes the duplication directly on `main`, referencing both original PRs in its description, rather than reverting either one.
