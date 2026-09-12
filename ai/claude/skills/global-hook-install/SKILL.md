---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: global-hook-install
description: One-shot setup that installs ai-skills' advisory reminder hooks (git-ops-reminder, pr-open-staleness-nudge, branch-guard-missing-nudge, issue-create-reminder, issue-update-reminder, ticket-write-verify-reminder, and their PostToolUse tracker companions) into the user's global ~/.claude/settings.json, so they fire in every repo instead of only inside ai-skills' own tracked settings. Use when the user asks to "install the reminder hooks globally", "make git-ops-reminder fire everywhere", "wire up reminders in every repo", "why didn't git-ops nudge me in that other repo", or after noticing a session skipped a skill in a non-ai-skills repo with no hook to catch it. Does not touch branch-guard.py, branch-guard-track.py, or cursor-ide-commit-guard.py — those are enforcement hooks, not advisory reminders, and are out of scope here.
compatibility: Requires python3 and write access to ~/.claude/settings.json. The install command must be run by the user in their own terminal — Claude Code cannot write that file directly (see update-config).
---

# Global Hook Install

`ai-skills`' advisory reminder hooks are wired by default only in this repo's own tracked `.claude/settings.json`. A session working in any other repo — `homelab-infra`, a client repo, a personal project — gets no nudge at all, because nothing installs the same hooks into the user's **global** `~/.claude/settings.json`. That gap is exactly what let ai-skills#611 happen: a session skipped `git-ops` from memory with no hook present to catch it. The pattern is universal, not ai-skills-specific — it's the same gap `branch-guard-missing-nudge.py` (built for #689) closes for the `branch-guard.py` enforcement hook, applied here to the reminder hooks instead.

This skill runs once. It doesn't add a new hook itself — it hands the user a single idempotent command that merges the existing reminder-hook entries into their global settings file, so every repo they work in gets the same nudges `ai-skills` already gets for free.

## Why a new skill instead of a git-ops addition

`git-ops`'s own "Automated reminder hook" and "PR-open staleness nudge" sections already document the JSON block for one hook at a time, routed manually through `update-config` into whichever repo's settings the user names. That's fine for a single hook added deliberately to a single repo. This ticket asks for something different: install *all six* current reminder hooks (plus their tracker companions) into the *global* file in one pass. Bolting that onto `git-ops`'s Setup section would mean either duplicating five more JSON blocks inline there or cross-referencing back to this file anyway — a dedicated skill keeps the "install everywhere, once" concern separate from `git-ops`'s per-operation guidance, and gives this specific one-shot action its own trigger phrases instead of overloading `git-ops`'s already-large description.

## 1. Confirm the current hook list from the source of truth

Don't install from memory — the set of default-wired reminder hooks can change as this repo adds more. Read this repo's own tracked settings to get the authoritative, current list before generating the install command:

```bash
cat .claude/settings.json
```

As of this skill's last update, the reminder/tracker hooks wired by default in `ai-skills`' own `.claude/settings.json` are:

| Hook script | Event / matcher | Companion tracker |
| --- | --- | --- |
| `git-ops-reminder.py` | `PreToolUse` / `Bash` | `git-ops-track.py` (`PostToolUse` / `Skill`) |
| `pr-open-staleness-nudge.py` | `PreToolUse` / `Bash` | none (stateless) |
| `branch-guard-missing-nudge.py` | `PreToolUse` / `Bash` | none (self-contained session-flag file) |
| `issue-create-reminder.py` | `PreToolUse` / `Bash`, `mcp__.*jira_create_issue`, `mcp__.*save_issue`, `mcp__.*issue_write` | `issue-create-track.py` (`PostToolUse` / `Skill`) |
| `issue-update-reminder.py` | `PreToolUse` / `Bash` | `issue-update-track.py` (`PostToolUse` / `Skill`) |
| `ticket-write-verify-reminder.py` | `PreToolUse` / `mcp__.*(jira_add_comment\|jira_update_issue\|confluence_update_page)` | `ticket-write-verify-track.py` (`PostToolUse` / `Skill`) |

**Out of scope, do not install**: `branch-guard.py`, `branch-guard-track.py` (enforcement, blocks commits on a real mismatch — not advisory), and `cursor-ide-commit-guard.py` (enforcement on `Edit|Write` — not a reminder). `skill-review-reminder.py` is also excluded — it's a different reminder family, not one of the six this ticket scopes.

If the table above no longer matches what `.claude/settings.json` actually contains, trust the file and update the install command in Step 2 accordingly rather than the stale table.

## 2. Hand the user the install command — never run it yourself

`~/.claude/settings.json` is on the user's own `Edit` deny-list, the same constraint `update-config` documents (see `hooks/inline-bash-hooks.md`: "applying any of these is a manual step"). This skill follows the same mechanism `update-config` already uses for hook entries — a `python3` script using the stdlib `json` module, not `jq` — extended to merge several matcher blocks in one pass instead of one entry at a time.

Print this block for the user to paste into their own terminal. Do not execute it via the Bash tool on their behalf.

```bash
python3 <<'PYEOF'
import json, os

path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}

hooks = data.setdefault("hooks", {})

def add(event, matcher, command):
    blocks = hooks.setdefault(event, [])
    entry = {"type": "command", "command": command}
    target = next((b for b in blocks if b.get("matcher") == matcher), None)
    if target is None:
        blocks.append({"matcher": matcher, "hooks": [entry]})
        return "added (new matcher block)"
    if not any(h.get("command") == command for h in target["hooks"]):
        target["hooks"].append(entry)
        return "added (existing matcher block)"
    return "already present"

installs = [
    ("PreToolUse", "Bash", "python3 ~/.claude/hooks/git-ops-reminder.py"),
    ("PreToolUse", "Bash", "python3 ~/.claude/hooks/pr-open-staleness-nudge.py"),
    ("PreToolUse", "Bash", "python3 ~/.claude/hooks/branch-guard-missing-nudge.py"),
    ("PreToolUse", "Bash", "python3 ~/.claude/hooks/issue-create-reminder.py"),
    ("PreToolUse", "Bash", "python3 ~/.claude/hooks/issue-update-reminder.py"),
    ("PreToolUse", "mcp__.*jira_create_issue", "python3 ~/.claude/hooks/issue-create-reminder.py"),
    ("PreToolUse", "mcp__.*save_issue", "python3 ~/.claude/hooks/issue-create-reminder.py"),
    ("PreToolUse", "mcp__.*issue_write", "python3 ~/.claude/hooks/issue-create-reminder.py"),
    ("PreToolUse", "mcp__.*(jira_add_comment|jira_update_issue|confluence_update_page)", "python3 ~/.claude/hooks/ticket-write-verify-reminder.py"),
    ("PostToolUse", "Skill", "python3 ~/.claude/hooks/git-ops-track.py"),
    ("PostToolUse", "Skill", "python3 ~/.claude/hooks/issue-create-track.py"),
    ("PostToolUse", "Skill", "python3 ~/.claude/hooks/issue-update-track.py"),
    ("PostToolUse", "Skill", "python3 ~/.claude/hooks/ticket-write-verify-track.py"),
]

for event, matcher, command in installs:
    result = add(event, matcher, command)
    print(f"{event} / {matcher}: {command.split('/')[-1]} -> {result}")

with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
```

**This is idempotent** — running it again (on this machine, or a fresh one after `repo-setup`) reports `already present` for every entry rather than duplicating them. That's what makes it safe to hand out as a standing one-shot recipe rather than something that needs to be run exactly once and never again.

## 3. Confirm the scripts actually exist on disk

The command above only edits JSON — it doesn't deploy the hook scripts themselves. If this machine has never run `make install-system` in `ai-skills`, the entries will point at files that don't exist yet, and every matching tool call will fail with a missing-script error instead of printing a nudge. Check before declaring success:

```bash
for f in git-ops-reminder.py pr-open-staleness-nudge.py branch-guard-missing-nudge.py \
         issue-create-reminder.py issue-update-reminder.py ticket-write-verify-reminder.py \
         git-ops-track.py issue-create-track.py issue-update-track.py ticket-write-verify-track.py; do
  [[ -f ~/.claude/hooks/"$f" ]] && echo "OK: $f" || echo "MISSING: $f"
done
```

Any `MISSING:` line means running `make install-system` from an `ai-skills` checkout first, then re-running the check.

## 4. This is one-shot — say so explicitly

Unlike the reminder hooks themselves (which are designed to fire repeatedly, once per relevant tool call, for the life of every future session), this skill's job ends once the JSON merge above has run successfully on a given machine. There is no companion tracker for *this* skill, and it should not re-fire automatically — a session that already confirmed the entries are present (Step 3 all `OK:`) has nothing further to do here. Re-run it only when: a new machine is being set up, a new reminder hook is added to `ai-skills`' own default set and needs to reach existing machines too, or the user explicitly asks to re-check.

## Related

- **ai-skills#611** — the incident that motivated this: a session skipped `git-ops` from memory in a repo where the reminder hook happened to be present, but the underlying "no hook installed, no nudge" pattern is universal to every repo without it.
- **ai-skills#689** — built `branch-guard-missing-nudge.py`, the same "install it globally, one time" idea applied to the `branch-guard.py` *enforcement* hook rather than the advisory reminders this skill covers.
- **`git-ops`** — documents each reminder hook's purpose and the manual per-repo `update-config` JSON block; this skill is the one-shot global equivalent, not a replacement.
- **`update-config`** — this skill's install command follows the same `python3`/stdlib-`json` mechanism `update-config` already uses for hook entries, because `~/.claude/settings.json` can't be written by Claude Code directly.
