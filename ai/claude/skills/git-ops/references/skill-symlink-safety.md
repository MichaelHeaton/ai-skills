---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Worktree path safety when editing

**General principle**: whenever an isolated worktree session is active, verify any Edit/Write's resolved absolute path actually lands inside that worktree before writing — regardless of how the path was reached. A deployed skill symlink is the most common way this drifts, but it's not the only one; a stale `cwd`, a wrong repo clone, or any other path-resolution mismatch can produce the same failure. Apply the same check-before-write discipline whenever paths and worktrees are both in play, not just for symlinks.

## General check — any path, not just symlinks

**Before an Edit/Write to any absolute path**, when an isolated worktree is active for the target repo, confirm the target's actual toplevel matches the worktree you intend to edit — this catches plain path mistakes (a stale `cwd`, a path typed or pasted without the worktree's prefix, a wrong clone) that never go through `~/.claude/skills/` at all and so wouldn't trip the symlink-specific check below:

```bash
git -C "$(dirname <target-path>)" rev-parse --show-toplevel
```

Compare the output against the intended worktree root. A mismatch means the write is about to land in the wrong checkout — stop and point at the correct worktree path instead of proceeding.

**Motivating incident**: during a 2026-07-30 session, several `Write`/`Edit` calls used an absolute repo path directly (not through `~/.claude/skills/`) without the active worktree's prefix. The mistake landed silently in the main checkout — caught only by chance when a post-commit `git status` in the worktree showed "nothing to commit." No data was lost, but the detection gap was real: the symlink-specific check below never fires when the path doesn't touch `~/.claude/skills/`.

## Special case — editing through a deployed skill symlink

`~/.claude/skills/<name>` is often a symlink into a repo's real checkout on disk. If a worktree branch is checked out for that same repo, an Edit/Write reached through the symlink path can resolve to the wrong on-disk location — e.g. the main checkout instead of the intended worktree. This is exactly how a stray edit can silently land on `main`: a real near-miss was caught only because a routine `git status` happened to run afterward, and it was reverted before any commit landed on `main`.

**Before an Edit/Write through a path under `~/.claude/skills/`**, resolve the real path and check for an active worktree on that repo:

```bash
# Resolve the symlink to its real on-disk location (a directory, not the SKILL.md file itself)
readlink -f ~/.claude/skills/<name>

# From the resolved path, check for active worktrees on the same repo
git -C "$(readlink -f ~/.claude/skills/<name>)" worktree list
```

**Why:** `readlink -f` shows where the symlink actually points — often the shared main checkout, not whatever worktree you meant to edit. `git worktree list` then shows every checkout for that repo, including any active non-main worktree branch.

**If an active non-main worktree exists for the same underlying repo**, warn before writing and point at the worktree checkout path instead of silently proceeding on whatever the symlink resolved to.

**If `git worktree list` returns more than one non-main entry**, don't assume — disambiguate:

- **Primary signal**: if the session's own current working directory (or the path it was invoked from) is itself inside one of the listed worktree paths, that's the relevant one — use it without asking.
- **If cwd doesn't match any listed worktree** and multiple non-main worktrees exist, stop and ask the user which one is intended, listing the candidate paths and branches.
- Do **not** fall back to "most recently modified" or "first in the list" — either would recreate the same false-confidence failure this check exists to prevent.

```bash
# Safe — resolved the symlink, saw an active worktree, edited there instead
readlink -f ~/.claude/skills/git-ops
# -> /Users/you/Projects/personal/ai-skills/ai/claude/skills/git-ops
git -C /Users/you/Projects/personal/ai-skills worktree list
# -> /Users/you/Projects/personal/ai-skills            <main>
# -> /Users/you/Projects/personal/ai-skills/.claude/worktrees/agent-xyz  <fix/some-branch>
# Edit lands in the worktree checkout, not the main one

# Risky — edit through the symlink path with no worktree check
# [Edit ~/.claude/skills/git-ops/SKILL.md directly, unaware a worktree branch is active]
```
