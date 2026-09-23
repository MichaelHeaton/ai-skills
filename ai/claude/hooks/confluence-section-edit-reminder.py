#!/usr/bin/env python3
"""PreToolUse hook: nudge toward invoking the confluence-section-edit skill
when a direct confluence_update_page/confluence_add_label call is about to
run and neither confluence-section-edit nor doc-coauthor (which owns the
full-page case) has fired yet this session. Advisory only — always exits 0,
never blocks the call. Companion to confluence-section-edit-track.py, which
records when either skill fires."""
import json
import re
import sys
from pathlib import Path

TOOL_RE = re.compile(r"(confluence_update_page|confluence_add_label)\b")

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = str(data.get("tool_name", ""))
if not TOOL_RE.search(tool_name):
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".confluence-section-edit-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[confluence-section-edit] Direct Confluence write detected and neither "
    "confluence-section-edit nor doc-coauthor has fired yet this session — "
    "this call won't get the section-scoping, double-JSON-decode, or "
    "image-macro-flattening safeguards. Consider invoking the "
    "confluence-section-edit skill before this call, unless it's already "
    "routed through doc-coauthor's own flow."
)
