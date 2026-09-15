#!/usr/bin/env python3
"""PreToolUse hook (Bash): warn when another live Claude Code session appears
to be working the same repo right before a PR/MR is opened. Advisory only —
always exits 0, never blocks PR creation. Resolves ai-skills#346's
pre-PR-creation branch by reusing session-close's own detection script
(check-concurrent-session.sh) rather than building a second mechanism —
see that ticket's resolution comment and principles/core.md's "Decision
authority" section.

Stdout must be empty or valid JSON: Cursor PreToolUse rejects plain-text
nudge lines as invalid JSON and blocks the tool call.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

_SEP = r"(?!&&|\|\||;|\|)"
_FLAGS = rf"(?:\s+{_SEP}\S+){{0,6}}"
COMMAND_RE = re.compile(
    rf"\bgh{_FLAGS}\s+pr\s+create\b"
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

cwd = data.get("cwd") or "."
script = Path.home() / ".claude" / "skills" / "session-close" / "scripts" / "check-concurrent-session.sh"
if not script.exists():
    sys.exit(0)

try:
    result = subprocess.run(
        ["bash", str(script), cwd],
        capture_output=True, text=True, timeout=5,
    )
except Exception:
    sys.exit(0)

if not result.stdout.startswith("LIVE:"):
    sys.exit(0)

msg = (
    "[concurrent-session] Another Claude Code session appears to be active "
    "in this repo right now (" + result.stdout.strip() + "). Opening a PR "
    "from here risks a branch/HEAD collision with that session's own work — "
    "confirm a worktree isolates this change before proceeding."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}))
