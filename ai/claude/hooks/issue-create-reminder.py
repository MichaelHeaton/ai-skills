#!/usr/bin/env python3
"""PreToolUse hook: nudge toward invoking the issue-create skill when a
direct ticket-creation call is about to run and issue-create hasn't fired
yet this session. Advisory only — always exits 0, never blocks the call.
Companion to issue-create-track.py, which records when issue-create fires.

Covers two shapes of direct call, both bypassing issue-create's routing,
dedupe-search, and task-index steps:
  - Bash commands: `gh issue create` / `glab issue create`
  - Direct MCP tool calls: a tool name ending in `jira_create_issue` or
    `save_issue`, regardless of which MCP server prefix exposes it — the
    exact prefix varies by environment, so this matches on the method
    name rather than a hardcoded `mcp__<server>__` prefix.
"""
import json
import re
import sys
from pathlib import Path

BASH_COMMAND_RE = re.compile(r"\b(gh\s+issue\s+create|glab\s+issue\s+create)\b")
MCP_TOOL_RE = re.compile(r"(^|_)(jira_create_issue|save_issue)$", re.IGNORECASE)

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
elif MCP_TOOL_RE.search(tool_name):
    is_direct_call = True

if not is_direct_call:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".issue-create-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[issue-create] The issue-create skill hasn't been invoked yet this "
    "session — its routing, dedupe-search, and task-index steps haven't "
    "been confirmed for this ticket. Consider invoking the issue-create "
    "skill instead of this direct call."
)
