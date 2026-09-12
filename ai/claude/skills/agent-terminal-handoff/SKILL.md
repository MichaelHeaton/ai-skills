---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: agent-terminal-handoff
description: When a Cursor agent's PreToolUse hook hard-blocks a needed CLI command (git, gh, or similar), package the blocked command(s) into a copy-paste block for the user's own terminal, record exactly which steps were handed off, and state the explicit re-entry signal the agent is waiting for. Resumes the interrupted skill — most often post-merge-cleanup or session-close — at the correct mid-sequence step once the user confirms done, instead of restarting from scratch. Does not recommend disabling or bypassing the hook. Trigger on a PreToolUse block on a git/gh command inside a Cursor agent session, "the hook blocked my command", "I can't run this here", "cursor won't let me run git", or any point where a needed CLI step must be delegated to the user's own terminal.
compatibility: Cursor agent sessions (or any agent environment) where a PreToolUse hook can hard-block CLI tools. Cloud-compatible — no local-machine-only paths or tooling; the blocked command still runs in the user's own terminal.
---

# Agent Terminal Handoff

A Cursor agent's `PreToolUse` hook can hard-block a CLI command the current skill needs (typically `git` or `gh`). The correct response is to delegate the command to the user's own terminal — never to work around or disable the hook, since it exists for a reason this skill doesn't need to know or guess at.

## When this fires

A `PreToolUse` hook refuses a `git`/`gh` (or equivalent) command mid-skill, inside a Cursor agent session or any environment with an equivalent hard block. Observed effect: the tool call returns blocked/denied rather than running — treat that refusal itself as the trigger, not any assumption about what the hook checks for or why it blocked this particular command.

**Do not advise disabling, bypassing, or reconfiguring the hook as a fix.** If the user asks whether they can just turn it off, say that's their call to make in their own config — not something this skill recommends.

## 1. Package the blocked command(s)

Give the user a clean, copy-paste block containing exactly the command(s) that were blocked — nothing extra, nothing implied. Precede it with:

- **Which hook blocked it** — name it if the block message or config identifies it; otherwise say "a PreToolUse hook" rather than guessing at a name.
- **What the command was supposed to do** — one line, plain language (e.g. "delete the merged local branch `feat/x`").

```bash
<exact blocked command, one per block per the git-ops one-step-per-block convention>
```

If more than one command was blocked, package each as its own block in run order — don't merge an auth-dependent or state-changing step into the same block as the one before it.

## 2. Record which steps were handed off

State a short, structured list of every step being handed off — not a vague "I handed off some commands." This is what keeps a step from silently getting skipped when control returns.

```
Handed off (run these yourself):
1. <command> — <what it does>
2. <command> — <what it does>
```

Keep this list next to the copy-paste blocks so the user can check items off as they go.

## 3. Set the explicit re-entry signal

State plainly what confirmation the agent is waiting for before it resumes — never leave resumption ambiguous.

> Reply "done" once you've run the command(s) above, and I'll pick up at the next step.

Use the user's own confirmation word if they've already established one in this session; otherwise "done" is the default.

## 4. Resume the interrupted skill at the right step

The two most likely interrupted flows are `post-merge-cleanup` and `session-close` — both run multi-step git sequences that a hook block is likely to interrupt mid-way.

- **`post-merge-cleanup`**: its steps are pull main, remove worktree, delete branch, redeploy, check Actions run. If the block hit step 3 (branch delete), resume at step 4 (redeploy) once the user confirms the delete ran — don't re-pull main or re-check the worktree.
- **`session-close`**: its steps are numbered (Step 1 discover repos, Step 1b git-ops pre-flight, Step 2 uncommitted changes, Step 3 worktrees, Step 4 non-main branches, Step 5 prune, Step 6 skill hygiene, Step 6b memory diff, Step 7 permission hygiene, Step 8 lean context audit, Step 9 tickets, Step 10 summary). Resume at the step immediately after the one that contained the blocked command, for the same repo — don't restart the whole repo loop.

Before resuming, briefly re-confirm the handed-off command actually did what it was supposed to (e.g. `git branch --list <name>` for a delete) rather than trusting "done" alone — a user confirming "done" prematurely or a command that partially failed both look identical from the agent's side otherwise.

If the interrupted flow isn't `post-merge-cleanup` or `session-close`, use the same principle: resume at the step after the blocked one, in that skill's own step sequence, rather than restarting the skill from its beginning.

## Report

```
✓ blocked command(s) packaged and handed off (see list above)
✓ re-entry signal set: reply "done" to resume
→ waiting on user confirmation
```

Once the user confirms, add:

```
✓ handoff verified (<check performed>)
→ resuming <skill name> at step <N>
```
