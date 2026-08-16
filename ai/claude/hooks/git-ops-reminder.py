#!/usr/bin/env python3
"""PreToolUse hook (Bash): nudge toward invoking the git-ops skill when a
git commit/push or PR-creation command is about to run and git-ops hasn't
fired yet this session. Advisory only — always exits 0, never blocks the
command. Companion to git-ops-track.py, which records when git-ops fires."""
import json
import re
import sys
from pathlib import Path

COMMAND_RE = re.compile(r"\b(git\s+commit|git\s+push|gh\s+pr\s+create|glab\s+mr\s+create)\b")

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
if not COMMAND_RE.search(command):
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".git-ops-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[git-ops] The git-ops skill hasn't been invoked yet this session — its "
    "AGENT.md freshness check and pre-PR humanizer pass haven't been "
    "confirmed for this run. Consider invoking the git-ops skill before "
    "this commit/push/PR.",
    file=sys.stderr,
)
