#!/usr/bin/env python3
"""PostToolUse hook (Bash): updates branch-guard's recorded expectation
whenever this session explicitly runs `git checkout`/`git switch`, so a
deliberate branch change isn't flagged as a collision by branch-guard.py on
the next commit. Companion to branch-guard.py (PreToolUse). Never blocks."""
import json
import re
import subprocess
import sys
from pathlib import Path

CHECKOUT_RE = re.compile(r"\bgit\s+(?:-C\s+(\S+)\s+)?(?:checkout|switch)\b")
STATE_DIR = Path.home() / ".claude" / ".branch-guard-sessions"

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
match = CHECKOUT_RE.search(command)
if not match:
    sys.exit(0)

repo_path = match.group(1) or "."
session_id = data.get("session_id") or "unknown"

try:
    toplevel = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
    actual = subprocess.run(
        ["git", "-C", repo_path, "branch", "--show-current"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not toplevel or not actual:
    sys.exit(0)

try:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / f"{session_id}__{toplevel.replace('/', '_')}").write_text(actual)
except Exception:
    pass
