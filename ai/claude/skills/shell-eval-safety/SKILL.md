---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: shell-eval-safety
description: Flag the anti-pattern `eval "$(some-login-command)"` in credential-sourcing shell — the eval expression's own exit code reflects whether the command substitution produced output, not whether the wrapped login/credential command actually succeeded, so a failed login that still prints something to stdout is silently treated as success. Trigger when writing or reviewing any `eval "$(...)"` construct that sources authentication or credential output (login scripts, token exchanges, env-var export helpers). Documents the safe replacement: capture stdout and `$?` separately, check the exit code, then `eval` only on confirmed success.
compatibility: Cloud-compatible — no local-machine-only paths or tooling.
---

# Shell Eval Safety

`eval "$(some-login-command)"` is a common way to source credentials or environment variables printed by a helper script. It is also a silent failure trap: the `eval` line's own exit status tells you whether the *substitution* produced output, not whether `some-login-command` actually succeeded.

## The anti-pattern

```bash
eval "$(./login.sh)"
```

If `login.sh` exits `1` (a failed login) but still prints *anything* to stdout — a partial export, a stale token, an error message formatted as shell — the command substitution `$(./login.sh)` succeeds (it produced output), so `eval` runs against that output and the whole line reports exit code `0`. The caller sees success. The login failure is swallowed.

This is dangerous specifically because it *looks* like standard error handling — `eval "$(...)" || die` still won't catch it, since `$?` after the pipeline reflects `eval`'s own parse/exec result on whatever text it was handed, not `login.sh`'s internal exit code.

## The safe replacement

Capture the subprocess's stdout and its own exit code **separately**, check the exit code, and only `eval` on confirmed success:

```bash
output=$(./login.sh)
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "login.sh failed (exit $rc): $output" >&2
  exit "$rc"
fi

eval "$output"
```

- `output=$(./login.sh)` captures stdout without yet acting on it.
- `rc=$?` grabs `login.sh`'s real exit code immediately — before any other command overwrites `$?`.
- The failure branch runs first and exits or returns before `eval` is ever reached.
- `eval "$output"` only executes once `rc` has already confirmed success.

## Before / after

**Before (swallows the failure):**

```bash
eval "$(./login.sh)"   # login.sh exits 1, but printed something —
                        # eval still reports success ($? == 0)
```

**After (surfaces the failure):**

```bash
output=$(./login.sh)
rc=$?
[[ $rc -eq 0 ]] || { echo "login.sh failed (exit $rc)" >&2; exit "$rc"; }
eval "$output"
```

## What to flag in review

Any `eval "$(...)"` where the inner command is a login, credential fetch, or token-exchange script — not general-purpose command substitution. Flag it even if the surrounding code has other error handling (a trailing `|| exit`, `set -e`), since none of those catch this specific failure mode: they all see `eval`'s exit code, never the wrapped command's.
