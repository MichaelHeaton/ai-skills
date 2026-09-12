---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: hook-env-compat
description: Audit PreToolUse/PostToolUse hook scripts under ai/claude/hooks/ for Cursor compatibility — flags a hook whose success-path stdout isn't valid JSON, or whose exit code is unconditionally non-zero, either of which Cursor can read as a hard block even when Claude Code would treat the same hook as purely advisory. Use after adding or editing a hook script, or during session-close's skill-review SA4 step when a Cursor block was actually observed on a matching tool call. Outputs a short flagged-script list with what's wrong and why; never fixes files or files tickets on its own. Trigger on "check hooks for Cursor compatibility", "will this hook block in Cursor", "audit hook stdout", "hook-env-compat", or a report that a hook hard-blocked a tool call in Cursor.
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Requires python3 (to read/execute candidate hooks) and read access to ai/claude/hooks/.
---

# Hook Env Compat

Claude Code and Cursor read a hook's stdout differently. A `PreToolUse`/`PostToolUse` hook written and tested only against Claude Code can pass every local check and still hard-block matching tool calls the first time it runs under Cursor.

## The compatibility gap

- **Claude Code**: treats a hook's plain stdout as advisory text — shown to the user, never parsed as a decision. A hook that just `print()`s a reminder and exits 0 is fine.
- **Cursor**: parses hook stdout as structured decision JSON, e.g. `{"decision": "block"/"approve", "reason": "..."}` (see the JSON shape `git-ops-reminder.py` and `pr-open-staleness-nudge.py` in this repo already emit — `{"hookSpecificOutput": {...}, "systemMessage": ...}`). If that stdout isn't valid JSON, or parses to a decision the author didn't intend, Cursor can treat it as a block instead of the advisory nudge it was meant to be.

A hook that also exits non-zero unconditionally compounds this — some environments read a non-zero exit itself as a block signal independent of stdout content. `branch-guard.py` in this repo is a deliberate example: it's meant to be an enforcement hook (`sys.exit(2)` on a real branch mismatch), not an advisory one, so an unconditional non-zero exit is correct there. The risk this skill scans for is an *advisory* hook that exits non-zero on a path meant to be informational only.

## The scan

For each script under `ai/claude/hooks/` that a `PreToolUse` or `PostToolUse` matcher references (check `.claude/settings.json` for the wired set — don't assume every file in the directory is active):

1. **Read the script's success/non-blocking path** — the branch that runs when nothing warrants a block (e.g. `git-ops-reminder.py`'s early `sys.exit(0)` returns when the command doesn't match, and its nudge path prints JSON and exits 0).
2. **Check what that path writes to stdout.** Flag it if:
   - It calls `print()` with a plain string (not run through `json.dumps` or equivalent) on a path meant to be advisory only.
   - It writes JSON, but the shape doesn't match Cursor's expected decision fields (`decision`, `reason`) or a documented hookSpecificOutput shape — verify against a script in this repo already confirmed working (`git-ops-reminder.py`, `pr-open-staleness-nudge.py`) rather than assuming a shape from memory.
3. **Check the script's exit codes.** Flag a script that exits non-zero on every path (no `sys.exit(0)` early-return for the non-blocking case), unless its own docstring says it's an intentional enforcement hook.
4. **Read the docstring first** — every hook in this repo documents whether it's advisory or enforcement, and several (`git-ops-reminder.py`, `pr-open-staleness-nudge.py`) already state the Cursor-JSON requirement explicitly. Don't re-derive intent from behavior alone when the author already stated it.

Do not assert how Cursor's hook runtime is implemented beyond what's directly observable from this repo's own scripts and their docstrings — describe the compatibility gap as a stdout/exit-code contract mismatch, not as a claim about Cursor's internals you haven't verified.

## Output

Produce a short list, one line per flagged script:

```
<script>: <what's wrong> — <why it matters in Cursor>
```

Example: `some-hook.py: prints a plain-text nudge on the non-blocking path — Cursor will fail to parse this as decision JSON and may treat the call as blocked.`

If nothing is flagged, say so plainly (`No compatibility issues found in <N> hooks scanned`) — don't pad a clean result with hedging.

For any **high**-severity finding (a wired, currently-active hook that will hard-block real tool calls, not just a stylistic gap), offer — don't automatically file — a follow-up: routing it through **`issue-create`** (never `gh issue create` directly, per this repo's convention). Ask before creating anything.

## Trigger conditions

- **After adding or editing a hook** under `ai/claude/hooks/` — run this before wiring it into `.claude/settings.json`, since that's the point a new script's stdout/exit contract is easiest to get wrong.
- **During session-close's skill-review SA4 step**, but only when a Cursor block was actually observed on a matching tool call in the session — this is a targeted diagnostic, not a routine part of every skill-review pass.

## Test plan

Run against `git-ops-reminder.py` as it looked before ai-skills#475 (plain-text `print()` on the nudge path, no JSON) — must flag it. Run against the current version in this repo (JSON via `json.dumps`, early `sys.exit(0)` on no-match) — must pass, or show residual notes only.
