---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
---

# Live concurrent-session detection

The "Shared checkout branch-identity check" and `session-close`'s own concurrent-session check both catch *effects* of a second session — a swapped branch, a merged PR found at session-close time. Neither catches a second Claude Code session **actively writing to this exact repo right now**, mid-edit, before either of those symptoms shows up.

**Detect it before committing**, not just at session-close:

```bash
# Other Claude Code processes with --add-dir pointing at this repo
ps aux | grep -- '--add-dir' | grep -F "<repo-path>" | grep -v grep

# Files under this repo modified more recently than this session started
# (SESSION_START_TS: capture `date +%s` once, early in the session)
find <repo-path> -type f -not -path '*/.git/*' -newermt "@${SESSION_START_TS}"
```

A hit on the `ps aux` check is a genuine candidate for a live second session — cross-check with `session-close`'s `scripts/check-concurrent-session.sh` if it's available, since it already excludes this session's own process by PID ancestry and `--add-dir` match rather than naively matching every `claude` process against the repo path.

A hit on the `find -newermt` check is only meaningful if the modified file isn't one *this* session itself just wrote — diff the result against the files this session has actually touched before treating it as evidence of another writer.

**Recovery, once a live collision is confirmed:**

1. **Don't stage, commit, or stash the other session's in-progress edit.** It isn't yours to resolve — touching it can hand you a half-finished change, or destroy work the other session hasn't saved yet.
2. **Wait for it to finish**, or confirm with the user it's safe to proceed.
3. **Once confirmed done, don't just continue on the branch it was found on** — that branch may already be merged or otherwise stale from the other session's own commits. Start a fresh branch off the updated default branch (`git checkout main && git pull && git checkout -b <new-branch>`, per git-ops's branching rule) and move this session's own changes there instead.

This is the same "fresh branch off updated main" recovery as the rebase-conflict case in [rebase-conflicts.md](rebase-conflicts.md) — the trigger differs (a live collision vs. a stale multi-commit rebase), but continuing on a branch whose ancestry has moved out from under you is the same mistake either way.

## Signal-triggered nudge before live Edit-tool use

The detection above fires "before committing" — a git-ops trigger point. Real loss can happen earlier than that: a session runs several Edit/Write calls against a shared checkout, and only discovers a collision once git-ops finally checks pre-commit — by which point the edits may already have been silently absorbed into another session's stash (see `session-close`'s transcript-reconciliation check for how that shows up after the fact).

**Ownership: `git-ops`, not `session-close`.** `git-ops` already fires on the first git operation of a session and every one after, giving it the earliest and broadest reach into a session's git activity; `session-close` only runs at the very end, when a loss has already happened.

**When a repo already shows recent-activity or branch-churn signals**, that's reason to get ahead of a possible collision rather than wait for the pre-commit check:

```bash
# Recent commits from *anyone*, not just this session — signals the repo is "hot"
git -C <repo-path> log -5 --oneline --since="1 hour ago"

# Local branches created/updated recently — signals active branch churn
git -C <repo-path> for-each-ref --sort=-committerdate \
  --format='%(committerdate:relative) %(refname:short)' refs/heads | head -5
```

If either shows activity from **outside this session** (a commit author or timestamp this session didn't produce), nudge toward one of:

- **Isolate in a worktree** — `git worktree add <path> -b <branch>` before making further Edit/Write changes in this repo, so a concurrent session sharing the main checkout can't stash or clobber this session's edits.
- **Commit more frequently** — rather than batching several Edit/Write changes before the first commit, commit each logical chunk as it's finished, shrinking the window where uncommitted work is exposed to a concurrent collision.

This is a nudge, not a gate — advisory the same way the rest of this check is, and it doesn't block any Edit/Write call. Run it once per repo, the first time this session is about to make an Edit/Write change there — not on every subsequent edit.
