---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
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

`check-concurrent-session.sh` excludes this session's own claude process (walked up from its own `$PPID`) before matching — a naive `lsof -c claude | grep <repo>` always matches the running session's own cwd, which is a guaranteed false positive on every invocation, not a real signal. It also separates output into `LIVE:<pid>:<cwd>` (the cwd directory still exists — a genuine candidate for another active session) and `STALE:<pid>:<cwd>` (the process's reported cwd no longer exists on disk, e.g. a worktree deleted earlier in this same session — not a live collision, safe to ignore).

The PPID-ancestor walk alone can miss a process that's genuinely "this session" but isn't a direct ancestor of the script's own `$$` (e.g. a sibling helper process). To catch that, the script also compares each remaining candidate's `--add-dir` argument list against its own session's — an exact match is treated as self and excluded, even without an ancestry link. Regression test: `scripts/check-concurrent-session.test.sh`.

If either signal fires — a `LIVE` match, or unexpected commits on `origin/main` this session didn't make — surface a warning before proceeding: *"Another session may be operating on `<repo>` — origin has moved / a concurrent process was found. Proceed carefully or check with the user before committing."* Ignore `STALE` matches; they aren't evidence of a live collision. This is best-effort, not a hard gate — don't block the run over it, and don't over-trust a clean result as proof no one else is active.

**Hard gate — per repo, not a one-time audit.** Completing this check for one repo does not clear the gate for any other repo still pending. Do not begin Step 2 for a given repo until this check has completed for that specific repo. If the check flags a merged PR (stale branch) **and** the repo has uncommitted changes, resolve those changes first via Step 2's normal flow (commit+push to the stale branch, discard, or leave pending) **while still on the stale branch**. Only once the working tree is clean, switch to `main` (`git checkout main && git pull`). Never check out `main` while changes are uncommitted, and never commit directly on `main` — any further work after switching needs a new branch per git-ops first. A repo skipped due to a `gh` failure does not satisfy this gate — flag it in Step 10 as "branch state unverified" and treat it as if a stale branch were possible (don't let Step 2 silently assume it's clean).
