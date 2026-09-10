#!/usr/bin/env python3
"""PreToolUse hook: nudge toward invoking the issue-update skill when a
direct ticket-update call is about to run and issue-update hasn't fired
yet this session. Advisory only — always exits 0, never blocks the call.
Companion to issue-update-track.py, which records when issue-update fires.

Covers direct Bash calls that bypass issue-update's status-sync, comment
verification, and task-index steps:
  - `gh issue comment|close|edit|reopen`
  - `glab issue note|close|update|reopen`

CLI-only — no MCP tool matching here. Direct MCP ticket-write calls
(`jira_add_comment`, `jira_update_issue`, `confluence_update_page`) are
already covered by ticket-write-verify-reminder.py.
"""
import json
import re
import sys
from pathlib import Path

BASH_COMMAND_RE = re.compile(
    r"\b(gh\s+issue\s+(comment|close|edit|reopen)|glab\s+issue\s+(note|close|update|reopen))\b"
)

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = str(data.get("tool_name", ""))
tool_input = data.get("tool_input", {}) or {}

is_direct_call = False
if tool_name == "Bash":
    command = str(tool_input.get("command", ""))
    is_direct_call = bool(BASH_COMMAND_RE.search(command))

if not is_direct_call:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".issue-update-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[issue-update] The issue-update skill hasn't been invoked yet this "
    "session — its status-sync, comment-verification, and task-index steps "
    "haven't been confirmed for this ticket. Consider invoking the "
    "issue-update skill instead of this direct call."
)
