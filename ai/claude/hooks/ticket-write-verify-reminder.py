#!/usr/bin/env python3
"""PreToolUse hook: nudge toward invoking the ticket-write-verify skill when a
direct jira_add_comment/jira_update_issue/confluence_update_page call is about
to run and neither ticket-write-verify nor issue-create/issue-update (which
run an inline version of the same check) has fired yet this session.
Advisory only — always exits 0, never blocks the call. Companion to
ticket-write-verify-track.py, which records when any of those skills fire."""
import json
import re
import sys
from pathlib import Path

TOOL_RE = re.compile(r"(jira_add_comment|jira_update_issue|confluence_update_page)\b")

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = str(data.get("tool_name", ""))
if not TOOL_RE.search(tool_name):
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".ticket-write-verify-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[ticket-write-verify] Direct ticket-system write detected and neither "
    "ticket-write-verify nor issue-create/issue-update has fired yet this "
    "session — this call won't get the pre-check or post-write verify-and-fix "
    "loop for known Jira/Confluence corruption modes. Consider invoking the "
    "ticket-write-verify skill before this call, unless it's already routed "
    "through issue-create/issue-update's own inline check."
)
