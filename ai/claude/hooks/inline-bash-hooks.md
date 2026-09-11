# Inline Bash `PreToolUse` hooks

The hook scripts in this directory (`git-ops-reminder.py`, `skill-review-reminder.py`, etc.) are files checked into this repo and deployed via `make install-system`. A different class of hook lives only as inline shell one-liners directly inside a user's live `~/.claude/settings.json` — short `jq`/`grep`/`exit 2` guardrails like "block `rm -rf`" or "block direct pushes to `main`". Those have never had a canonical copy tracked anywhere in this repo, so they can drift or get silently lost on a fresh machine setup with no record of what they were supposed to be.

**Decision**: track canonical copies of these inline hooks here going forward, one fenced block per hook, so a fresh `~/.claude/settings.json` can be reconstructed from this file. Claude Code cannot write `~/.claude/settings.json` directly — it's on the user's own `Edit` deny-list — so applying any of these is a manual step.

## Block `gh pr merge` / `glab mr merge`

Requires a human to perform the actual merge — Claude can review, rebase, and push a PR, but not merge it. Add as an entry in the `PreToolUse` array, matcher `Bash`:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if [[ ! -x /usr/bin/jq ]]; then echo 'WARN: jq not found; pr-merge hook disabled.' >&2; exit 0; fi; input=$(cat); cmd=$(echo \"$input\" | /usr/bin/jq -r '.tool_input.command // .input.command // empty'); if echo \"$cmd\" | /usr/bin/grep -qE '(^|[[:space:]])(gh[[:space:]]+pr[[:space:]]+merge|glab[[:space:]]+mr[[:space:]]+merge)([[:space:]]|$)'; then echo 'BLOCKED: PR/MR merges must be done by a human, not Claude, until better guardrails are in place. Merge this PR yourself in the GitHub/GitLab UI.' >&2; exit 2; fi"
    }
  ]
}
```

Scope: blocks `gh pr merge` / `glab mr merge` only — not `git push --force` (a separate deny rule) — and applies globally across all repos.

## Block recursive delete (`rm -rf` and variants)

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if [[ ! -x /usr/bin/jq ]]; then echo 'WARN: jq not found; recursive-rm hook disabled.' >&2; exit 0; fi; input=$(cat); cmd=$(echo \"$input\" | /usr/bin/jq -r '.tool_input.command // .input.command // empty'); if echo \"$cmd\" | /usr/bin/grep -qE '^\\s*rm\\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|(-[a-zA-Z]*f[a-zA-Z]*\\s+)?-[a-zA-Z]*r[a-zA-Z]*)\\s'; then echo 'BLOCKED: recursive delete detected. Use a scoped rm or trash instead.' >&2; exit 2; fi"
    }
  ]
}
```

## Block direct pushes to `main`/`master`

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if [[ ! -x /usr/bin/jq ]]; then echo 'WARN: jq not found; main-push hook disabled.' >&2; exit 0; fi; input=$(cat); cmd=$(echo \"$input\" | /usr/bin/jq -r '.tool_input.command // .input.command // empty'); if echo \"$cmd\" | /usr/bin/grep -qE '/usr/bin/git\\s+push\\s+\\S+\\s+(main|master)(\\s|$)'; then echo 'BLOCKED: pushing directly to main/master. Use a feature branch and create a PR instead.' >&2; exit 2; fi; if echo \"$cmd\" | /usr/bin/grep -qE '^\\s*/usr/bin/git\\s+push\\s*$'; then branch=$(/usr/bin/git branch --show-current 2>/dev/null); if [ \"$branch\" = main ] || [ \"$branch\" = master ]; then echo 'BLOCKED: pushing directly to main/master. Use a feature branch and create a PR instead.' >&2; exit 2; fi; fi"
    }
  ]
}
```

## Block pipe-to-shell (`curl|bash` and similar)

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if [[ ! -x /usr/bin/jq ]]; then echo 'WARN: jq not found; pipe-to-shell hook disabled.' >&2; exit 0; fi; input=$(cat); cmd=$(echo \"$input\" | /usr/bin/jq -r '.tool_input.command // .input.command // empty'); if echo \"$cmd\" | /usr/bin/grep -qE '(curl|wget)\\s.*\\|\\s*(bash|sh|zsh|dash|ksh|python|perl|ruby|node)'; then echo 'BLOCKED: pipe-to-shell pattern detected. Download the script first, review it, then run it.' >&2; exit 2; fi"
    }
  ]
}
```

## Block `find -exec`/`-delete`/`-fprint*`

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if [[ ! -x /usr/bin/jq ]]; then echo 'WARN: jq not found; find-exec hook disabled.' >&2; exit 0; fi; input=$(cat); cmd=$(echo \"$input\" | /usr/bin/jq -r '.tool_input.command // .input.command // empty'); if echo \"$cmd\" | /usr/bin/grep -qE '(^|\\s)find\\s.*-(exec|execdir|ok|okdir|delete|fprint|fprintf|fprint0)(\\s|$)'; then echo 'BLOCKED: find with -exec/-execdir/-delete/-fprint* can run arbitrary commands or modify files. Use a scoped command or request explicit approval.' >&2; exit 2; fi"
    }
  ]
}
```

These four were transcribed directly from a live, deployed `~/.claude/settings.json` (not from memory), so the tracked copy matches what's actually running.
