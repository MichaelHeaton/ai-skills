---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: gh-account-routing
description: Detect and switch to the correct gh account for a repo's owner before any gh command mid-session — not only at session boundaries — then restore the prior account once the triggering task completes. Use before any ad hoc gh call (checking a PR, viewing an issue, cloning) against a repo whose owner doesn't match the currently active gh account, especially when checking status across multiple repos in different GitHub orgs within one session. Complements session-close's own account pre-flight, which only runs at session start/end.
compatibility: Requires gh CLI with more than one account authenticated.
---

# GH Account Routing

`gh`'s active account can be wrong for the repo you're about to touch at any point mid-session, not just at session boundaries — session-close's own pre-flight only runs once, at the start of a close-out. This skill is the standalone version: run it before any mid-session `gh` call against a repo you haven't already confirmed the active account for.

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

## 3. Restore after the triggering task completes

Once the specific task that needed the switch is done — not the whole session — switch back:

```bash
gh auth switch --hostname github.com --user "${ORIGINAL_GH_ACCOUNT}"
```

**Don't leave the switched account active for the rest of the session** — the next unrelated `gh` call assumes the account it had before this task started.

## 4. Multiple repos across different orgs in one session

When checking PR/issue status across several repos that belong to different accounts (a personal check, then a work-org check, then back to personal), repeat steps 1–3 **per repo**, not once for the whole batch — don't assume the first switch covers every subsequent call. Group same-account calls together where the order is flexible, to minimize the number of switches.

## Relationship to session-close

`session-close`'s own `references/gh-auth-preflight.md` runs this same check once, at the start of a close-out run, and restores at Step 10. This skill is that logic made available for any mid-session moment a `gh` call needs it — not a replacement for session-close's pre-flight.
