---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: memex-commit-reconcile
description: After a shared (non-worktree) memex checkout's pending changes get silently absorbed into a concurrent session's own commit — detected the same way git-ops's "Live concurrent-session detection" does, via reflog entries or a HEAD commit not authored by this session's own `git add`/`git commit` — verify that each file this session originally intended to commit actually survived, and report a clean per-file confirmation instead of requiring manual `git reflog` plus ad hoc diffing. Trigger on "did my changes make it in", "check if my edits survived that commit", "someone else committed over my changes", "verify my memex changes are in HEAD", "my staged changes got absorbed", "reconcile my commit", or immediately after git-ops's concurrent-session detection confirms another session committed while this one had pending work. Also useful any time a session needs to confirm a specific list of files' content matches what it intended, regardless of how the absorption happened.
compatibility: Requires git; assumes a non-worktree (shared) checkout where concurrent-session collisions are possible — see git-ops's "Live concurrent-session detection" for how the collision itself is detected.
---

# Memex Commit Reconcile

A shared, non-worktree memex checkout lets two concurrent sessions write to the same working tree. When that happens, one session's staged-but-uncommitted changes can get folded into the other session's commit instead of landing as their own clean commit — the file ends up in HEAD, but nobody confirmed its *content* is actually what the first session intended. Confirming that by hand means `git reflog`, `ps aux`, and per-file diffing done fresh every time. This skill turns that into a repeatable check.

This skill does not detect the collision itself — that's git-ops's "Live concurrent-session detection" (reflog entries and commits not authored by this session's own `git add`). Run this skill once that detection has already told you another session's commit may contain your work.

## 1. Collect the intended file list

Get the list of files this session meant to commit, and (if still available) their intended content:

- If the session still has the pre-collision diff in context (e.g. from its own `git diff` output before the collision), use that as ground truth.
- Otherwise, ask the user which files they were working on, or check `git reflog` for this session's own `git add`/`git commit` attempts around the time of the collision to reconstruct the list.

Without a concrete file list, there is nothing to reconcile — don't guess at scope from the whole repo diff.

## 2. Find the absorbing commit

Use `git reflog` to find the commit that landed at HEAD around the time of the collision:

```bash
git -C <repo> reflog --date=iso -20
```

Identify the commit hash that is not attributable to this session (not the session's own `git commit` invocation, per git-ops's detection signals). That commit is the one to check content against.

## 3. Check each file's survival

For each file in the intended list, compare its content in the absorbing commit (or current HEAD, whichever is later) against what this session intended:

```bash
git -C <repo> show <commit>:<path> > /tmp/reconcile-actual-<n>
diff /tmp/reconcile-actual-<n> <path-to-intended-content>
```

If the session's own pre-collision diff is available instead of a saved intended-content file, compare against that diff's post-image directly rather than re-fetching a stashed copy.

Classify each file into exactly one of three states:

- **present-and-matches** — the file exists in HEAD and its content is byte-identical (or semantically identical for generated files) to what this session intended.
- **present-but-differs** — the file exists in HEAD but its content diverges from what this session intended (partial absorption, a merge conflict resolved differently, or the other session's edit overwrote part of it).
- **missing** — the file that was intended to be committed is absent from HEAD entirely.

## 4. Report per-file, never silently pass

Report every file's classification, not just the ones that need attention — a silent pass on a file that actually differs is the exact failure mode this skill exists to prevent:

```
memex-commit-reconcile — <repo> @ <absorbing-commit>

✓ present-and-matches   Wiki/Concepts/foo.md
✓ present-and-matches   task-index.md
✗ present-but-differs   Wiki/People/bar.md  (diff below)
✗ missing               Wiki/Concepts/baz.md
```

For any `present-but-differs` or `missing` file, show the actual diff or absence, and ask the user how to proceed — reapply the missing/divergent content as a new commit, or confirm the other session's version is acceptable as-is. Never resolve a divergence unilaterally.

## What this skill is not

- Not a collision detector — that's git-ops's "Live concurrent-session detection."
- Not a merge or conflict-resolution tool — it reports state, the user decides what to do about a divergence.
- Not scoped to memex specifically in mechanism — the same per-file compare applies to any shared, non-worktree checkout, but it's filed here because memex's checkout pattern is where this has recurred (alongside `memex-decide`, `memex-dump`).
