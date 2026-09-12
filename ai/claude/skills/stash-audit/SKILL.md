---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: stash-audit
description: Scan tracked repos for git stashes older than a configurable threshold (default 30 days), summarize each stale stash's contents briefly, and prompt the user to apply, drop, or explicitly defer it — closing the gap where stale WIP survives indefinitely with no owner ever re-prompted. Complements session-close's repo-discovery step (which handles worktrees and branches but not stashes) and can also run ad hoc, outside a full session-close pass. Trigger on "check for old stashes", "stash audit", "any stale stashes", "clean up my stashes", "what's sitting in stash", or when session-close's repo discovery surfaces a repo with a non-empty stash list.
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Requires git. Deferral filing path uses the deferred-scope-record skill's own tooling.
---

# Stash Audit

Find git stashes that have quietly sat unresolved for too long, summarize them briefly, and force an explicit decision — apply, drop, or defer — instead of letting them survive indefinitely as silent WIP.

## Relationship to session-close

`session-close`'s repo-discovery step checks for uncommitted changes and unmerged worktree branches, but does not currently inspect the stash stack. Run `stash-audit` alongside or right after that discovery step for full coverage, or invoke it standalone any time outside a session-close run. Neither skill re-implements the other's checks.

## Steps

### 1. Enumerate stashes per repo

For each repo of interest:

```bash
git -C <repo> stash list
```

Skip repos with an empty stash list — nothing to audit.

### 2. Check each stash's age

```bash
git -C <repo> log -1 --format=%cd --date=relative stash@{N}
```

(Use `--date=iso` instead of `--date=relative` if you need an exact cutoff comparison against the threshold.) Default staleness threshold is **30 days** — ask the user once if they want a different threshold for this pass, otherwise use the default.

### 3. Summarize stale stashes briefly

For any stash at or past the threshold, show a short summary — never the full diff:

```bash
git -C <repo> stash show stash@{N}
```

A diffstat (files touched + line counts) is enough context for a decision. Only fall back to `git stash show -p stash@{N}` for a specific hunk if the user asks to see more before deciding.

### 4. Prompt per stale stash: apply, drop, or defer

**⚠️ Before acting on any stash below**: the stash stack is shared across worktrees and concurrent sessions on the same repo. Never run a bare `git stash pop` or `git stash drop` against a shared stack without first confirming which entry is whose — identify it by message/tag and re-resolve its current `stash@{N}` index right before acting, since indices shift as other entries are pushed or popped. See `git-ops`'s guidance on concurrent-session stash safety for the fuller rationale; this skill just applies it at audit time.

Present each stale stash (repo, age, one-line summary) and ask the user to choose:

- **Apply now** — `git stash apply stash@{N}` (not `pop`, so the stash entry survives until the user confirms the working tree is right, then drop it explicitly).
- **Drop** — `git stash drop stash@{N}`.

  **⚠️ Never drop without explicit per-stash confirmation.** A dropped stash is gone — there's no recovery path as reliable as just asking first. Never batch-drop multiple stashes off one blanket "yes, clean them all up."

- **Defer explicitly** — don't just leave it. Suggest filing it via `deferred-scope-record` (global: ai-skills) so the deferral has a durable unblock condition (a ticket or vault note) rather than silently surviving as unowned WIP for another audit cycle.

### 5. Report

One line per repo: how many stale stashes found, and the resolution (applied / dropped / deferred to `<ticket-or-note>`) for each. If a repo had no stale stashes, say so — don't stay silent.
