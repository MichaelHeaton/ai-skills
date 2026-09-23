#!/usr/bin/env python3
"""PostToolUse hook (Skill): record that confluence-section-edit or
doc-coauthor fired this session, so confluence-section-edit-reminder.py's
PreToolUse nudge can tell whether a direct Confluence write call is already
covered instead of assuming so from habit. Never blocks."""
import json
import sys
from pathlib import Path

TRACKED_SKILLS = {"confluence-section-edit", "doc-coauthor"}

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
skill = str(tool_input.get("skill", "")).strip().lower()
if skill not in TRACKED_SKILLS:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_dir = Path.home() / ".claude" / ".confluence-section-edit-sessions"
try:
    flag_dir.mkdir(parents=True, exist_ok=True)
    (flag_dir / session_id).touch()
except Exception:
    pass
