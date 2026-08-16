---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
---

# Transcript-vs-working-tree reconciliation (Step 1 detail)

A concurrent session sharing the same non-worktree checkout can pick up this session's own uncommitted Edit/Write changes into its own `git stash` — silently, before either session commits them. Neither the concurrent-session check nor `discover-repos.sh`'s `CHANGES` count catches this: the working tree looks clean because the content really is gone from it, just not because it was ever committed.

## Procedure

Run this only for repos this session actually made Edit/Write tool calls against — skip repos only touched via Bash/git commands, or not touched this session at all.

1. **Build the touched-file list from the transcript, not from git.** This is this session's own record of which file paths it ran Edit/Write against for this repo — not a git command, since the whole point is comparing the transcript's claim against git's current state.

2. **Compare each file against the repo's actual state:**

   ```bash
   git -C <repo> status --short -- <file1> <file2> ...
   git -C <repo> log -1 --oneline -- <file1>
   ```

3. **Classify each file:**

   - **Appears in `git status` (staged or unstaged), or a recent commit's content matches the edit** → reconciled, no action needed.
   - **Clean/untracked-with-old-content, and no matching recent commit exists** → mismatch. Treat this as a **potential loss, not "nothing to commit."** Do not silently pass it through.

4. **On a mismatch, check for the content before concluding it's gone:**

   ```bash
   git -C <repo> stash list
   git -C <repo> reflog --oneline -20
   ```

   - **Content found in a stash entry this session didn't create** → this confirms the concurrent-stash-collision pattern. Recover it (`git stash show -p <stash>` to inspect, then `git stash apply <stash>` or a targeted `git checkout <stash> -- <file>` rather than a blind `pop`, since the stash may hold the *other* session's own uncommitted work mixed in with this session's lost edit) before treating this repo as clean, then re-run Step 2 for the affected files.
   - **Content found via reflog** (e.g. a commit that got reset or amended away) → cherry-pick or restore the specific content from that commit.
   - **Nothing recovers it** → flag prominently in the Step 10 summary as a likely data-loss incident requiring manual forensics. Don't guess further, and don't attempt destructive recovery commands (force-checkout, hard reset) without confirming with the user first — a wrong guess here can destroy the one copy of the lost content that still exists somewhere in the reflog/stash history.

## Why this is a Step 1 check, not a Step 2 check

Step 2 acts on whatever `git status` currently shows — by design, it has no way to know a file *should* have shown changes but doesn't. This check has to run before Step 2 starts trusting `CHANGES` as complete, so a silent loss gets caught before the session moves on to committing (or worse, discarding) a state that already has some of this session's own real edits missing from it.
