#!/usr/bin/env python3
"""UserPromptSubmit hook: nudge toward invoking the vault-support skill when a
pasted Slack link/thread about a policy-PR-shaped question comes in and
vault-support hasn't fired yet this session. Triggering is otherwise advisory
to model judgment with no mechanical enforcement (see #880/#882) — this is
the same session-flag pattern as ticket-write-verify-track.py and
confluence-section-edit-track.py, applied one level earlier (prompt text,
not a specific tool call about to run). Advisory only — always exits 0,
never blocks the prompt. Companion to vault-support-track.py, which records
when vault-support fires."""
import json
import re
import sys
from pathlib import Path

SLACK_URL_RE = re.compile(r"slack\.com/archives/", re.IGNORECASE)
VAULT_KEYWORD_RE = re.compile(
    r"policy pr|vault ticket|vault|kv2|approle|403|permission denied|access denied",
    re.IGNORECASE,
)

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

prompt = data.get("prompt", "")
if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(0)

if not SLACK_URL_RE.search(prompt):
    sys.exit(0)
if not VAULT_KEYWORD_RE.search(prompt):
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
flag_path = Path.home() / ".claude" / ".vault-support-sessions" / session_id
if flag_path.exists():
    sys.exit(0)

print(
    "[vault-support] Slack thread link plus a vault/policy-PR-shaped keyword "
    "detected and vault-support hasn't fired yet this session — this looks "
    "like the input shape vault-support exists for (fact-checking the "
    "support bot, spotting doc gaps). Consider invoking the vault-support "
    "skill before answering, unless this was already deliberately routed "
    "elsewhere (e.g. straight to comms-write for a reply-only ask)."
)
