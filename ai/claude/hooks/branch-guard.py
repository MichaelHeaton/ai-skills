#!/usr/bin/env python3
"""PreToolUse hook (Bash): blocks a `git commit` when the active branch in a
shared (non-worktree) checkout no longer matches this session's own recorded
expectation — catches a second process silently swapping branches out from
under a shared checkout before a commit lands on the wrong one. Mechanizes
git-ops's "Shared checkout branch-identity check" as a hard block instead of
prose that has to be remembered and run manually.

Companion to branch-guard-track.py (PostToolUse), which records the
expectation whenever this session explicitly runs `git checkout`/`git
switch`. There's no SessionStart event in this repo's supported hook set
(PreToolUse, PostToolUse, Notification, Stop, SubagentStop), so "record on
session start" is approximated: the first commit with no recorded
expectation for a repo records the current branch as the baseline and
allows the commit, rather than blocking on a state that was never captured.

An isolated `git worktree` checkout is immune to this class of collision —
its branch is pinned to that worktree — so this always allows worktrees."""
import json
import re
import subprocess
import sys
from pathlib import Path

COMMIT_RE = re.compile(r"\bgit\s+(?:-C\s+(\S+)\s+)?commit\b")
STATE_DIR = Path.home() / ".claude" / ".branch-guard-sessions"

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
match = COMMIT_RE.search(command)
if not match:
    sys.exit(0)

repo_path = match.group(1) or "."
session_id = data.get("session_id") or "unknown"

try:
    toplevel = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not toplevel:
    sys.exit(0)

if (Path(toplevel) / ".git").is_file():
    sys.exit(0)  # worktree checkout — branch is pinned, can't collide

try:
    actual = subprocess.run(
        ["git", "-C", toplevel, "branch", "--show-current"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not actual:
    sys.exit(0)

state_file = STATE_DIR / f"{session_id}__{toplevel.replace('/', '_')}"
if not state_file.exists():
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        state_file.write_text(actual)
    except Exception:
        pass
    sys.exit(0)

expected = state_file.read_text().strip()
if expected == actual:
    sys.exit(0)

print(
    f"BLOCKED: this session expected branch '{expected}' in {toplevel}, but "
    f"'{actual}' is checked out now — another process likely swapped it in "
    f"this shared checkout. Confirm which branch is actually correct before "
    f"committing; do not commit onto whatever happens to be checked out.",
    file=sys.stderr,
)
sys.exit(2)
