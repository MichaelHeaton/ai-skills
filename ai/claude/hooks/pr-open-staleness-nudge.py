#!/usr/bin/env python3
"""PreToolUse hook (Bash): nudge toward running the skill-staleness-check
skill when a PR/MR-creation command is about to run. Advisory only —
always exits 0, never blocks PR creation. Fires on ai-skills#470: PR-open
is the concrete trigger for a passive skill-staleness audit, so the user
doesn't have to remember to invoke it manually."""
import json
import re
import sys

COMMAND_RE = re.compile(r"\b(gh\s+pr\s+create|glab\s+mr\s+create)\b")

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
if not COMMAND_RE.search(command):
    sys.exit(0)

print(
    "[skill-staleness-check] Opening a PR — consider running the "
    "skill-staleness-check skill to compare local skill versions against "
    "what's uploaded to the claude.ai Skills store before this merges.",
)
