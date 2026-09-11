#!/usr/bin/env python3
"""PreToolUse hook (Bash): nudge, once per repo per session, when the repo
about to receive a `git commit` doesn't have branch-guard.py wired at all —
neither in its own .claude/settings.json nor in the global
~/.claude/settings.json, or the hook script itself is missing from disk.
Advisory only — always exits 0, never blocks the commit. Mechanizes
git-ops's "One-time nudge when the guard is missing entirely" section
instead of leaving it as a prose-only instruction to remember.

Stdout must be empty or valid JSON: Cursor PreToolUse rejects plain-text
nudge lines as invalid JSON and blocks the tool call."""
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / ".branch-guard-missing-sessions"
SEPARATOR_RE = re.compile(r"&&|\|\||[;|]")
GLOBAL_HOOK_PATH = Path.home() / ".claude" / "hooks" / "branch-guard.py"


def find_commit_invocation(command: str):
    for fragment in SEPARATOR_RE.split(command):
        try:
            tokens = shlex.split(fragment)
        except ValueError:
            continue
        if not tokens or tokens[0] != "git":
            continue
        i = 1
        repo_path = "."
        if i < len(tokens) and tokens[i] == "-C" and i + 1 < len(tokens):
            repo_path = tokens[i + 1]
            i += 2
        if i < len(tokens) and tokens[i] == "commit":
            return repo_path
    return None


def wires_branch_guard(settings_path: Path) -> bool:
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        return False
    pre_tool_use = (settings.get("hooks", {}) or {}).get("PreToolUse", []) or []
    for entry in pre_tool_use:
        for hook in entry.get("hooks", []) or []:
            if "branch-guard.py" in str(hook.get("command", "")):
                return True
    return False


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
repo_path = find_commit_invocation(command)
if repo_path is None:
    sys.exit(0)

try:
    toplevel = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not toplevel:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
digest = hashlib.sha256(toplevel.encode()).hexdigest()[:16]
flag_path = STATE_DIR / f"{session_id}__{digest}"
if flag_path.exists():
    sys.exit(0)

repo_settings = Path(toplevel) / ".claude" / "settings.json"
global_settings = Path.home() / ".claude" / "settings.json"

wired = (
    (repo_settings.exists() and wires_branch_guard(repo_settings))
    or (global_settings.exists() and wires_branch_guard(global_settings))
)
hook_script_present = GLOBAL_HOOK_PATH.exists()

if wired and hook_script_present:
    sys.exit(0)

flag_path.parent.mkdir(parents=True, exist_ok=True)
flag_path.touch()

msg = (
    "[branch-guard] This repo doesn't have branch-guard.py wired (checked "
    f"{repo_settings} and {global_settings}), or the hook script itself is "
    "missing from ~/.claude/hooks/ — a second process silently swapping "
    "the active branch in a shared checkout wouldn't be caught here. "
    "Install it via the update-config skill (see git-ops's 'Shared "
    "checkout branch-identity check' section for the JSON block) if this "
    "repo uses a shared, non-worktree checkout."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}))
