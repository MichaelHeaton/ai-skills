---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: shell-backend-fallback
description: Detect when the parent session's Bash/Shell tool itself has failed — "no exit status" or another execution-backend error — distinct from a hook block (tied to one command) or `gh` simply being absent (command-not-found). Retry the parent Bash tool once for a transient hiccup; on a second identical failure, delegate remaining git/gh work to a `shell` subagent (Agent tool, subagent_type "shell") with an ordered, copy-paste-ready command list and absolute repo paths. Covers building the prompt, collecting results, resuming the parent flow, and noting delegated steps in a session summary. Trigger on "no exit status", "shell tool failed", "bash backend error", "the shell tool isn't working", "commands aren't running", repeated identical backend failures with no command-specific error text, or git/gh work continuing despite an unusable Bash tool. See body for how this differs from `sandbox-blocked-op-router`, `agent-terminal-handoff`, `sandbox-exec-delegate`, and `session-close` (inline version this generalizes).
compatibility: Requires the Agent tool with a "shell" subagent type available. If "shell" isn't a recognized subagent_type in this environment, fall back to "general-purpose" with an explicit shell-only prompt (Step 3 covers both).
---

# Shell Backend Fallback

The parent session's Bash/Shell tool can fail in three different shapes that look similar but call for different responses. This skill covers only one of them: the execution backend itself failing, not a specific command being rejected or missing. Confuse the three and you either retry forever against a broken backend, or delegate work that a plain retry would have fixed.

## Step 1 — Identify the failure shape

Before doing anything else, classify what actually happened:

- **Execution-backend failure (this skill)** — the Bash/Shell tool returns "no exit status", times out with no stdout/stderr at all, or reports an execution-backend/session error that isn't tied to the command's own semantics. The same failure would happen for *any* command run through that tool right now, not just this one.
- **Hook block (not this skill)** — a PreToolUse/PreCommand hook rejects the command and returns a specific block message, a distinct non-zero exit code, or hook-authored text explaining why. This is a decision about *that command*, not a backend fault. See `agent-terminal-handoff` if the block is a hard Cursor hook block that needs a human-run terminal instead.
- **`gh` absent (not this skill)** — a normal "command not found" / "gh: command not found" error. The backend ran the command fine; the binary just isn't installed or on `PATH`. See `git-ops`'s gh-CLI-availability section and `issue-create`'s MCP fallback reference instead.
- **Network-unreachable (not this skill)** — `kubectl`/`ssh`/`curl` to a private/LAN-only host times out or refuses the connection while the shell tool itself is working fine. See `sandbox-exec-delegate`.

If the output has no command-specific error text at all — just "no exit status," a raw timeout, or a generic backend/session error — treat it as an execution-backend failure and continue to Step 2.

## Step 2 — Retry once, then stop retrying

One retry is reasonable: a single dropped connection or transient hiccup in the execution backend is common and usually self-resolves.

- Re-run the **exact same command**, unchanged, through the parent Bash tool.
- If it now returns a normal exit status (success or a real command-level error), the backend has recovered — proceed normally, no delegation needed.
- If it fails **the same way again** — same "no exit status" or backend-error shape, not a new command-specific error — the backend itself is broken, not the command. Stop retrying and move to Step 3.

Do not retry a third time, and do not try "creative" workarounds in the parent Bash tool (different shells, `nohup`, backgrounding) to route around a broken backend — those still depend on the same broken execution path. Delegate instead.

## Step 3 — Delegate to a `shell` subagent

Use the Agent tool with `subagent_type: "shell"` if that type is available in this environment. If it is not recognized, fall back to `subagent_type: "general-purpose"` and make the prompt explicitly shell-only (no exploration, no judgment calls — just run the listed commands and report output).

Construct the delegation prompt so the subagent needs no context beyond what's in it:

1. **State the situation in one sentence** — the parent session's Bash tool is failing with an execution-backend error (not a hook block, not a missing binary), so this work is being delegated.
2. **Give the absolute repo path(s)** — never a relative path. A subagent has no memory of the parent's working directory.
3. **List every git/gh command to run, in order, as a numbered list** — one command per step, exactly as it should be typed. Do not summarize multiple steps into one bullet ("commit and push") when they are separate commands; spell each one out.
4. **State what output to return for each step** — the git/gh command's own stdout/stderr, not a paraphrase, plus the exit status if the subagent's tool surfaces one. For a step that produces a URL (`gh pr create`, `git push` with a compare link), explicitly ask for that URL verbatim.
5. **Say what NOT to do** — don't merge, don't force-push, don't skip a step because it "looks redundant," don't improvise additional commands beyond the list.

**Worked example:**

> The parent session's Bash tool is returning "no exit status" on two consecutive attempts — the execution backend is broken, not this specific command. Delegating the remaining git steps to you.
>
> Repo: `/Users/example/Projects/personal/ai-skills` (absolute path — `cd` there first if your tool needs it, but always pass this same absolute path to any command that also takes a path argument).
>
> Run these in order and report each one's full stdout/stderr:
>
> 1. `git -C /Users/example/Projects/personal/ai-skills status --short`
> 2. `git -C /Users/example/Projects/personal/ai-skills add ai/claude/skills/example-skill/SKILL.md`
> 3. `git -C /Users/example/Projects/personal/ai-skills commit -m "Add example-skill"`
> 4. `git -C /Users/example/Projects/personal/ai-skills push -u origin feat/example-skill-123`
> 5. `gh pr create --repo example-org/ai-skills --base main --head feat/example-skill-123 --title "Add example-skill" --body "..."`
>
> Return the exact output of each command, and the PR URL from step 5 verbatim. Do not merge the PR. Do not run any command not listed above.

## Step 4 — Collect results and resume the parent flow

When the subagent reports back:

- Treat its reported command output the same way you would have treated your own Bash tool's output — read it, don't re-summarize it as an assumption.
- Verify the claim before building on it when the stakes justify it (a reported commit or push is easy to double-check with a read-only command like `git log` or `gh pr view` — run that through the parent Bash tool if it's recovered, or through the same subagent if not).
- If a step's output is missing, ambiguous, or doesn't match what was asked for, send the subagent one targeted follow-up for that specific step — don't re-issue the whole list.
- Resume the original task (the skill or workflow that was mid-flight when the backend failed) at the step right after the last delegated one, using the subagent's results as the input that step needed.

**Before delegating each additional batch of steps**, retry the parent Bash tool with a small no-op command (e.g. `git status`) first — the backend may have recovered on its own. Only keep delegating if it's still failing the same way.

## Step 5 — Note delegated steps in any session summary

When a session summary, PR description, or handoff note is produced afterward, call out which git/gh actions ran via the subagent rather than the parent tool. A human reading the summary needs to know that those steps didn't run in the environment they think they did — this matters for debugging (a delegated step ran with the subagent's own permissions/tooling, not the parent's) and for trust (the parent session couldn't directly verify the subagent's environment matched its own).

State it plainly, e.g.: "Steps 2–4 (commit, push, PR create) ran via a `shell` subagent because the parent session's Bash tool returned a persistent execution-backend error — see git/gh output above for what actually ran." Don't bury this in a footnote after a wall of otherwise-normal-looking status lines; it belongs near the top of the summary, next to any other caveats.

## Cross-references

- **`session-close`** — documents this same detect/retry-once/delegate pattern inline, scoped to its own repo-checklist steps. This skill is the generalized, standalone version other skills or ad hoc sessions can reference by name instead of re-describing the pattern.
- **`agent-terminal-handoff`** — for a Cursor PreToolUse hook block on git/gh, not a backend fault; hands the command to the human's own terminal instead of a subagent.
- **`sandbox-exec-delegate`** — for genuine network unreachability (kubectl/ssh/curl to a private host), not an execution-backend failure; hands a copy-paste command to the human operator instead of a subagent.
- **`sandbox-blocked-op-router`** — for permission/account-restricted gh/git calls, not a backend fault.
- **`subagent-completion-verify`** and **`subagent-edit-verify`** — run these after the subagent reports back, before trusting its "completed" status or claimed file changes as durable.
