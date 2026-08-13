#!/usr/bin/env python3
"""PostToolUse hook (Skill): record that the git-ops skill fired this
session, so git-ops-reminder.py's PreToolUse nudge can tell whether it was
actually invoked instead of assuming so from habit. Never blocks."""
import json
import sys
from pathlib import Path

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
skill = str(tool_input.get("skill", "")).strip().lower()
if skill != "git-ops":
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_dir = Path.home() / ".claude" / ".git-ops-sessions"
try:
    flag_dir.mkdir(parents=True, exist_ok=True)
    (flag_dir / session_id).touch()
except Exception:
    pass
