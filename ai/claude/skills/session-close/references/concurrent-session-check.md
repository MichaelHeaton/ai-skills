---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
---

# Concurrent-session check (best-effort, non-blocking)

Before committing anything in a repo, do a lightweight check for a second session already operating on it — a stale-state check alone only catches a *past* session, not one running right now:

```bash
# Another claude process with a cwd inside this repo?
bash ~/.claude/skills/session-close/scripts/check-concurrent-session.sh <repo>

# Has origin moved since this session started, outside anything this session did?
git -C <repo> fetch origin --dry-run 2>&1
git -C <repo> log HEAD..origin/main --oneline
```

`check-concurrent-session.sh` excludes this session's own claude process (walked up from its own `$PPID`) before matching — a naive `lsof -c claude | grep <repo>` always matches the running session's own cwd, which is a guaranteed false positive on every invocation, not a real signal. It also separates output into `LIVE:<pid>:<cwd>` (the cwd directory still exists — a genuine candidate for another active session), `STALE:<pid>:<cwd>` (the process's reported cwd no longer exists on disk, e.g. a worktree deleted earlier in this same session — not a live collision, safe to ignore), and `CLEAR:<repo>` (no `LIVE` or `STALE` match at all). Reference the script's actual `LIVE`/`STALE`/`CLEAR` output by name when running this check — the same way `check-branch-identity.sh`'s `MATCH`/`MISMATCH` output is referenced by name in Step 1 — so a skipped or half-remembered check leaves a detectable gap in the transcript instead of being silently bypassable.

The PPID-ancestor walk alone can miss a process that's genuinely "this session" but isn't a direct ancestor of the script's own `$$` (e.g. a sibling helper process). To catch that, the script also compares each remaining candidate's `--add-dir` argument list against its own session's — an exact match is treated as self and excluded, even without an ancestry link. Regression test: `scripts/check-concurrent-session.test.sh`.

If either signal fires — a `LIVE` match, or unexpected commits on `origin/main` this session didn't make — surface a warning before proceeding: *"Another session may be operating on `<repo>` — origin has moved / a concurrent process was found. Proceed carefully or check with the user before committing."* Ignore `STALE` matches; they aren't evidence of a live collision. This is best-effort, not a hard gate — don't block the run over it, and don't over-trust a clean result as proof no one else is active.

**Supplementary signal — reflog freshness.** Both checks above have come back clean against a real, live collision in practice — a second session actively committing to the same checkout, invisible to `check-concurrent-session.sh` and the origin-move check alike, only caught afterward via anomalous `git reflog` entries. As a cheap additional cross-check, capture `SESSION_START_TS=$(date +%s)` once, at the very start of Step 1, before any git command runs — then compare the repo's reflog against it:

```bash
git -C <repo> reflog --since="@${SESSION_START_TS}" --oneline
```

Every entry here should map to something this session itself did (its own checkouts, commits, merges). An entry that doesn't — a commit, checkout, or stash this session didn't perform — is treated the same as a `LIVE` match: surface the same warning before proceeding. This signal is strongest early in a session, before its own git activity has piled up enough reflog entries to make "mine vs. not mine" tedious to eyeball; it's still best-effort, not a substitute for the two checks above.

**Hard gate — per repo, not a one-time audit.** Completing this check for one repo does not clear the gate for any other repo still pending. Do not begin Step 2 for a given repo until this check has completed for that specific repo. If the check flags a merged PR (stale branch) **and** the repo has uncommitted changes, resolve those changes first via Step 2's normal flow (commit+push to the stale branch, discard, or leave pending) **while still on the stale branch**. Only once the working tree is clean, switch to `main` (`git checkout main && git pull`). Never check out `main` while changes are uncommitted, and never commit directly on `main` — any further work after switching needs a new branch per git-ops first. A repo skipped due to a `gh` failure does not satisfy this gate — flag it in Step 10 as "branch state unverified" and treat it as if a stale branch were possible (don't let Step 2 silently assume it's clean).

## Worktree isolation for Step 10's git mutations

Detection alone — `LIVE`/`STALE`/`CLEAR`, the origin-move check, reflog freshness — only helps if it happens to run at the right moment. It cannot catch a second, *live* session that checks out a different branch on the same shared, non-worktree checkout in the gap between this session's own `git checkout`/`git add` and its own `git commit`/`git push` — by the time any of the signals above would fire again, the mutation has already landed on whatever branch happened to be current at commit time. An earlier fix hardened the *stale*-branch case (a branch whose recorded state had drifted since this session last touched it, caught by `check-branch-identity.sh`'s `MATCH`/`MISMATCH` check in Step 1b) — that check runs once, before a repo's work begins, so it does not cover a branch pointer that moves again *during* this session's own sequence of git calls.

Step 10's memex session-summary write/commit/push sequence is the highest-risk instance of this: it runs late in the session, after everything else, in the same shared checkout every other step used — exactly the conditions for another session's concurrent activity to have moved the branch pointer since Step 1b last checked it. Rather than re-checking branch identity between every individual git call in the sequence, do the mutation somewhere a second session's checkout can't reach it:

```bash
git -C <repo> fetch origin --quiet
git -C <repo> worktree add <repo>/.claude/worktrees/session-close-<run-id> -b <summary-branch> origin/<default-branch>
```

Run the write/commit/push sequence inside `<repo>/.claude/worktrees/session-close-<run-id>` instead of `<repo>` itself — a worktree has its own `HEAD`, so another session switching the shared checkout's current branch cannot move it out from under this one, by construction. This is the same isolation `EnterWorktree`/git-ops already use for coding-agent work, applied here to session-close's own git mutations. Once pushed and confirmed (`git ls-remote --heads origin <summary-branch>`), remove the worktree (`git worktree remove <path>`) rather than leaving it behind for the next session to trip over.

This applies at minimum to Step 10's session-summary sequence; extend it to any other session-close git mutation in a shared, non-worktree checkout where the concurrent-session risk above is a real concern for that repo.
