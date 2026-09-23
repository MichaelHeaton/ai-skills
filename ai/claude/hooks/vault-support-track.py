#!/usr/bin/env python3
"""PostToolUse hook (Skill): record that vault-support fired this session, so
vault-support-reminder.py's UserPromptSubmit nudge can tell whether a pasted
Slack thread + policy-PR/vault question is already covered instead of
assuming so from habit. Never blocks."""
import json
import sys
from pathlib import Path

TRACKED_SKILLS = {"vault-support"}

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {})
if not isinstance(tool_input, dict):
    tool_input = {}
skill = str(tool_input.get("skill", "")).strip().lower()
if skill not in TRACKED_SKILLS:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_dir = Path.home() / ".claude" / ".vault-support-sessions"
try:
    flag_dir.mkdir(parents=True, exist_ok=True)
    (flag_dir / session_id).touch()
except Exception:
    pass
