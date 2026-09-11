---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: gh-account-routing
description: Detect and switch to the correct gh account for a repo's owner before any gh command mid-session — not only at session boundaries — then restore the prior account once the triggering task completes. Use before any ad hoc gh call (checking a PR, viewing an issue, cloning) against a repo whose owner doesn't match the currently active gh account, especially when checking status across multiple repos in different GitHub orgs within one session. Also invoke this immediately after any gh command fails with a repository-resolution error (e.g. GraphQL "could not resolve to a Repository") — that failure signature is a documented entry point in its own right, not just something a pre-flight check should have caught. Complements session-close's own account pre-flight, which only runs at session start/end.
compatibility: Requires gh CLI with more than one account authenticated.
---

# GH Account Routing

`gh`'s active account can be wrong for the repo you're about to touch at any point mid-session, not just at session boundaries — session-close's own pre-flight only runs once, at the start of a close-out. This skill is the standalone version: run it before any mid-session `gh` call against a repo you haven't already confirmed the active account for.

**Reactive entry point:** a `gh` command failing with a repository-resolution error (`GraphQL: Could not resolve to a Repository`, or similar) is itself a valid trigger for this skill, not just a signal to fix manually. Run Steps 1-3 below starting from that failure the same way you would from a proactive pre-flight check — the restore-after-completion step in Step 3 applies regardless of which way this skill was entered.

## 1. Check the target repo's owner against the active account

```bash
gh auth status 2>&1 | grep "Logged in to github.com account"
```

Compare the active account against the owner of the repo you're about to call `gh` against. If they match, proceed — no switch needed.

## 2. Switch if mismatched

Capture the current account first so it can be restored:

```bash
ORIGINAL_GH_ACCOUNT=$(gh auth status 2>&1 | grep "Active account: true" -B1 | grep "Logged in to github.com account" | awk '{print $(NF-1)}')
gh auth switch --hostname github.com --user "<target-repo-owner-account>"
```

**Always pass `--hostname github.com`.** With more than one host authenticated (github.com plus an internal GHE/GitLab host), `gh auth switch --user <name>` fails outright without the hostname flag — it isn't optional once more than one host is in play.

**After switching, unset any stale `GH_TOKEN` before exporting a fresh one, then verify it's non-empty** — under sandbox execution, `gh auth status` succeeding does not guarantee `GH_TOKEN` is actually set in the shell environment, and a stale value from a prior switch or the ambient sandbox environment silently overrides `gh auth token`'s fresh lookup (same guard `issue-update` already uses):

```bash
unset GH_TOKEN
export GH_TOKEN=$(gh auth token --user "<target-repo-owner-account>")
[[ -n "$GH_TOKEN" ]] || echo "GH_TOKEN still empty after switch" >&2
```

## 3. Restore after the triggering task completes

Once the specific task that needed the switch is done — not the whole session — switch back:

```bash
gh auth switch --hostname github.com --user "${ORIGINAL_GH_ACCOUNT}"
```

**Don't leave the switched account active for the rest of the session** — the next unrelated `gh` call assumes the account it had before this task started.

## 4. Multiple repos across different orgs in one session

When checking PR/issue status across several repos that belong to different accounts (a personal check, then a work-org check, then back to personal), repeat steps 1–3 **per repo**, not once for the whole batch — don't assume the first switch covers every subsequent call. Group same-account calls together where the order is flexible, to minimize the number of switches.

## 5. Session-scoped lock mode

Steps 1-4 above are the default: switch before each mismatched call, restore right after. That's the safer choice when the account you need varies from one `gh` call to the next. But when a session repeatedly targets the *same* non-default account, the switch-restore-switch cycle becomes needless overhead.

**Canonical example: Memex as a constant companion repo.** A session that uses `memex` as a working-log/second-brain alongside almost any other task ends up interleaving `memex` calls with calls against whatever repo is the actual focus — hitting the same-account switch 5+ times in a row. The mechanism below isn't Memex-specific; it applies to any repeated-same-account pattern, Memex is just the case that motivated it.

### When lock mode applies

Every `gh` operation for the rest of the session/task targets the same non-default account. Lock mode replaces the per-call switch/restore cycle with a single switch, for as long as that account stays the active target.

### Entering lock mode

Two triggers, both requiring confirmation before locking — this is never a silent behavior change:

- **Explicit**: the user says something like "lock to `<account>`" or otherwise signals they'll be jumping to that account repeatedly this session. Switch once per Step 2 and treat it as locked — no need to ask for confirmation, the user already gave it.

- **Automatic offer**: track a per-account switch counter for the session, not a strict "back-to-back" adjacency requirement — an intervening switch to a *different* account does not reset another account's count. The **2nd time this session** the target account is switched to (regardless of what happened in between), offer to lock rather than silently repeating the per-call cycle a 3rd time. For example: "This is the second time this session switching to `<account>` — want me to lock to it for the rest of the session instead of switching back and forth?" Wait for a yes before changing behavior; if the user declines, keep using per-call switching.

### What lock mode does

Once confirmed:

1. **Capture the true pre-lock account** before switching — `gh auth status` right now, not whatever `session-close`'s own pre-flight might see later. This is the account lock mode is ultimately responsible for restoring; don't rely on any other skill's pre-flight to have captured it correctly, since a skill invoked *after* the lock is already active only ever sees the locked account as "current," not the original.
2. Switch to the target account (Step 2), same as normal.
3. Skip the restore-after-task step (Step 3) for every subsequent call to that account — stay switched.
4. **Restore explicitly, as its own step, before the task or session that needed the lock is considered done** — either when the user explicitly says they're finished with that account, or before handing off to any other skill that does its own account pre-flight (`session-close` included). Don't defer restoration to "session end" as a passive backstop: nothing restores the account automatically if the session simply ends without an explicit unlock, and `session-close`'s own pre-flight/restore cycle is designed to undo *its own* temporary switch — it has no visibility into an unrelated lock already in effect when it starts, so running it does not reliably restore the true pre-lock account.

### Default stays per-call switching

Lock mode is opt-in per session, entered only via one of the two triggers above. A session that never hits the repeated-same-account pattern — or that declines the automatic offer — behaves exactly as it does today, with Steps 1-4 as the only path.

## Relationship to session-close

`session-close`'s own `references/gh-auth-preflight.md` runs this same check once, at the start of a close-out run, and restores at Step 10. This skill is that logic made available for any mid-session moment a `gh` call needs it — not a replacement for session-close's pre-flight.

**If lock mode is still active when `session-close` runs, restore it first, explicitly, before invoking `session-close`.** Session-close's own pre-flight captures whatever account is active *when it starts* as the "original" account to restore to at its Step 10 — it has no way to know a lock was already in effect before it started, so it will treat the locked account as correct and restore right back to it, not to the true pre-lock account. Session-close's Step 10 restore and lock mode's own restore (above) are two independent mechanisms with no automatic handoff between them.
