---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: background-agent-commit-scope-guard
description: Pre-commit check that verifies a background or capture agent's staged files match only what it was actually asked to touch, before it runs git add/git commit in a shared, non-worktree checkout. Prevents — rather than only detecting after the fact — a background agent sweeping unrelated in-progress edits from a concurrent session into its own commit and onto someone else's open PR branch. Use before any git add/git commit issued by a background agent, capture skill, or automated pass (memex captures, ledger appends, wiki updates) running against a shared checkout rather than its own worktree; also use as a manual gut-check whenever "git status shows more changes than I expected" before committing. Complements, does not replace, session-close's own detection references (concurrent-session-check.md, merged-branch-push-safety.md, duplicate-content-race-check.md) — those catch collisions after they happen; this stops the commit before it can sweep in unrelated files.
compatibility: Requires git. Assumes the agent's task scope (the file list or directory it was actually asked to touch) is known or can be reconstructed from the task prompt.
---

# Background Agent Commit Scope Guard

A background or capture agent working in a shared, non-worktree checkout can pick up another session's uncommitted edits without meaning to — `git add` and `git commit` don't know which files belong to which task. The fix is a scope check that runs **before** the commit, not a post-hoc diff review after the branch is already shared.

## Why this exists

Two real incidents in this repo trace to the same root cause: a background agent's `git add`/`git commit` in a shared checkout picked up files it wasn't asked to touch.

- A capture agent's wiki-index edit swept into an unrelated, already-open PR branch left over from an earlier same-day session. That PR squash-merged before a follow-up fix-up could land, producing duplicated content on `main` (see `session-close`'s `references/duplicate-content-race-check.md`).
- A concurrent session sharing the same checkout switched branches mid-run, and a commit landed on the wrong branch entirely (see `session-close`'s `references/concurrent-session-check.md` and `references/merged-branch-push-safety.md`).

Both were caught and repaired after the fact. This skill is the "before" half: refuse the commit if its staged scope doesn't match its assigned scope.

## Step 1 — Know the task's actual scope before touching git

Before any `git add`, write down (or have the calling agent state) the exact file list or directory scope it was asked to touch — e.g. "only `Wiki/log.md` and `CRM/Meeting/2026-09-14-Slack-topic.md`," not "the vault." A vague scope ("update the wiki") can't be checked against; require the calling task to be specific enough to diff against.

## Step 2 — Compare staged files against that scope

After `git add` but before `git commit`, run:

```bash
git diff --name-only --cached
```

Compare every path in that output against the declared scope from Step 1. Any path not covered by the scope is a violation.

## Step 3 — On a scope violation, stop and unstage — never commit through it

```bash
# Unstage everything and inspect before re-adding only the intended paths
git restore --staged .
git add <only the files actually in scope>
git diff --name-only --cached   # re-verify before committing
```

**⚠️ Never `git commit` while an out-of-scope file is staged, even "just this once."** Unstaging costs nothing; a swept-in file on someone else's PR branch costs a repair PR (see the incidents above).

If the extra staged file turns out to be a real uncommitted edit from a concurrent session (not garbage), do not commit it on the agent's behalf — leave it staged-then-restored so the other session finds its work intact, and flag the collision to the user rather than silently resolving it.

## Step 4 — Prefer a worktree over this check when one is available

This guard is a safety net for shared checkouts specifically. If the calling task can run in its own `git worktree` instead (most backlog/agent work can), do that instead — a worktree makes scope drift structurally impossible rather than merely checked-for. Reach for this skill when a worktree genuinely isn't an option (a lightweight capture pass, a hook context, or a tool that only operates against the primary checkout).

## Step 5 — Wire it as a pre-commit hook (optional, for repeated use)

For a repo where background agents commit frequently, encode Steps 2–3 as a local pre-commit hook rather than relying on the agent to remember:

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit (or a scripts/scope-guard.sh called from CI)
scope_file="${AGENT_SCOPE_FILE:-.agent-scope}"
if [[ -f "$scope_file" ]]; then
  staged="$(git diff --name-only --cached)"
  while IFS= read -r f; do
    grep -qxF "$f" "$scope_file" || {
      echo "scope-guard: '$f' is staged but not in declared scope ($scope_file)" >&2
      exit 1
    }
  done <<< "$staged"
fi
```

The calling agent writes its declared scope to `.agent-scope` (one path per line) before staging; the hook refuses the commit on any mismatch. Delete `.agent-scope` after a successful commit so it doesn't stick around as stale state for the next commit.
