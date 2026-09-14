#!/usr/bin/env python3
"""PreToolUse hook (Bash): nudge toward invoking the git-ops skill when a
git commit/push or PR-creation command is about to run and git-ops hasn't
fired yet this session. Advisory only — always exits 0, never blocks the
command. Companion to git-ops-track.py, which records when git-ops fires.

Stdout must be empty or valid JSON: Cursor PreToolUse rejects plain-text
nudge lines as invalid JSON and blocks the tool call.
"""
import json
import re
import sys
from pathlib import Path

# Tolerate global flags between the binary and its subcommand (e.g.
# `gh --repo owner/repo pr create`, `git -C path commit`) without matching
# across a shell separator into an unrelated command. A "flag token" is any
# whitespace-separated chunk that doesn't itself start a new command.
_SEP = r"(?!&&|\|\||;|\|)"
_FLAGS = rf"(?:\s+{_SEP}\S+){{0,6}}"
COMMAND_RE = re.compile(
    rf"\bgit{_FLAGS}\s+commit\b"
    rf"|\bgit{_FLAGS}\s+push\b"
    rf"|\bgh{_FLAGS}\s+pr\s+create\b"
    rf"|\bglab{_FLAGS}\s+mr\s+create\b"
)

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {})
if not isinstance(tool_input, dict):
    tool_input = {}
command = str(tool_input.get("command", ""))
if not COMMAND_RE.search(command):
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".git-ops-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

msg = (
    "[git-ops] The git-ops skill hasn't been invoked yet this session — its "
    "AGENT.md freshness check and pre-PR humanizer pass haven't been "
    "confirmed for this run. Consider invoking the git-ops skill before "
    "this commit/push/PR."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}))
