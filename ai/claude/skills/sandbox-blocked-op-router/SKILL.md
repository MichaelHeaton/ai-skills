---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: sandbox-blocked-op-router
description: Triage a failed gh/git command in a sandboxed shell (this repo's own sandbox execution environment) into one of two unrelated root causes before picking a fix — sandbox ACL/permission restriction vs. wrong GitHub account context — since retrying with elevated permissions won't fix an account mismatch and switching accounts won't fix a sandbox restriction. Trigger on `git worktree add` failing outside the allowed root, a `.git/config` write being denied, an intermittent `GraphQL: Forbidden` on a mutating `gh` call, or any gh/git failure in a sandboxed shell where the cause isn't yet obvious. Walks through signatures per category, then routes sandbox-ACL cases to retry-with-elevated-permissions/delegate/ask-the-user, and account-mismatch cases to gh-account-routing. Complements gh-account-routing (account-switch mechanics) and issue-create (verified GraphQL: Forbidden sandbox-ACL precedent cross-referenced here).
compatibility: Requires a sandboxed shell tool (this repo's own sandbox execution environment) with a `required_permissions` escalation option, plus git and gh CLI.
---

# Sandbox Blocked-Op Router

A `gh` or `git` command failing inside a sandboxed shell can mean two unrelated things that need completely different fixes. Guessing wrong wastes a retry cycle at best and sends you down the wrong skill at worst — retrying with elevated shell permissions does nothing for a wrong-account problem, and switching accounts does nothing for a sandbox restriction. This skill triages the failure before routing.

## The two root causes

1. **Sandbox ACL / permission restriction** — not a credential problem. The sandboxed shell itself is scoping what the command is allowed to touch or reach.
2. **Wrong GitHub account context** — a real credential/identity problem. The active `gh` auth doesn't match the account the target repo needs (e.g. a work account hitting a personal repo, or vice versa).

Don't guess between them. Check signatures first.

## Step 1: Check the error text against each signature set

**Sandbox-ACL signatures** (points to cause 1):

- `git worktree add` fails on a path outside this session's allowed working directory or worktree root
- A write to `.git/config` (or another repo-internal file) is denied outright, not with a permissions/ownership error from the OS
- An intermittent `GraphQL: Forbidden` on a mutating `gh` call (`gh issue create`, `gh api --method POST`, etc.) that comes and goes across otherwise-identical invocations — this is the exact case `issue-create`'s Step 0.5 already documents and verified as a sandbox-ACL issue, not a token problem. See `ai/claude/skills/issue-create/SKILL.md` Step 0.5 for the confirmed precedent and its probe sequence.
- The failure is about *where* or *what* the command is allowed to do, not *who* it's authenticated as

**Account-mismatch signatures** (points to cause 2):

- The error names a repository-resolution problem (`GraphQL: Could not resolve to a Repository`) rather than a bare `Forbidden`
- `gh auth status` shows an active account whose org/namespace doesn't match the target repo's owner
- The same command already succeeds against a repo owned by the currently-active account, but fails only against repos owned by a different account
- A probe like `gh api user --jq .login` returns a login that clearly isn't the one the target repo expects

If the error text doesn't cleanly match either list, run the probe in Step 2 before deciding — don't route on a guess.

## Step 2: Probe when the signature is ambiguous

Confirm which account is actually active and whether it resolves correctly, independent of the failing command:

```bash
unset GH_TOKEN
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
gh api user --jq .login
```

- **Probe fails, or returns a login that doesn't match the target repo's expected owner** — this is cause 2 (account mismatch). Go to Step 3b.
- **Probe succeeds with the correct login, but the original command still fails** — the token and account are fine, so it isn't a credential problem. This is cause 1 (sandbox ACL). Go to Step 3a.

## Step 3a: Sandbox ACL — fix in this shell, or hand off

Try these in order; stop at whichever succeeds:

1. **Retry with elevated shell permissions.** Re-run the same command with the shell tool's `required_permissions: ["all"]` option — this is the same escalation `issue-create` Step 0.5 uses for its `GraphQL: Forbidden` case.
2. **Delegate to a subagent or different execution context** that has broader shell access than the current sandboxed session, if elevated permissions aren't available or don't help.
3. **Ask the user to run the command from their own terminal.** Some sandbox restrictions (e.g. a hard deny on paths outside the worktree root) aren't things a permission flag can lift — hand the exact command back to the user rather than looping on retries that will keep failing the same way.

Do not route this case to `gh-account-routing` — the account is not the problem, and switching accounts will not touch a sandbox restriction.

## Step 3b: Account mismatch — hand off to gh-account-routing

Route to the **`gh-account-routing`** skill *(global: ai-skills)* rather than attempting a permissions fix here. That skill owns the switch-and-restore mechanics for moving between valid, working `gh` accounts; this skill's job ends at correctly identifying that the failure is an account problem, not a sandbox one.

Do not retry with `required_permissions: ["all"]` for this case — elevated shell permissions don't change which GitHub account is authenticated, so the retry will fail again with the same error.

## Notes

- Both root causes can present as the same surface symptom (a failed `gh`/`git` call with an opaque error), which is why Step 1's signature check — and Step 2's probe when signatures are ambiguous — comes before any fix attempt, not after.
- This skill describes observed failure signatures and a verified precedent (`issue-create` Step 0.5), not the sandbox's internal implementation — treat any unlisted error text as ambiguous and run the Step 2 probe rather than assuming which category it falls into.
