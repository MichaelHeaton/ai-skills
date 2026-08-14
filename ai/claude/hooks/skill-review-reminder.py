#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): nudge to offer skill-review's single-skill
mode whenever a SKILL.md file was just edited directly, so the reminder
fires even in a session where skill-review itself was never invoked and its
own proactive-trigger prose never entered context. Advisory only, always
exits 0, never blocks. Harmless if it also fires during skill-create's own
flow, which already runs review as part of creation."""
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

file_path = str(data.get("tool_input", {}).get("file_path", ""))
if not file_path.endswith("SKILL.md"):
    sys.exit(0)

print(
    "[skill-review] A SKILL.md was just edited directly — consider offering "
    "the skill-review skill's single-skill mode on it before treating this "
    "edit as done."
)
