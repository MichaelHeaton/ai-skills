#!/usr/bin/env python3
"""PostToolUse hook (Bash): updates branch-guard's recorded expectation
whenever this session explicitly runs `git checkout`/`git switch`, so a
deliberate branch change isn't flagged as a collision by branch-guard.py on
the next commit. Companion to branch-guard.py (PreToolUse). Never blocks.

Uses the same shlex-tokenized invocation detection as branch-guard.py —
see that file's docstring for why a substring match on the raw command
text isn't good enough."""
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / ".branch-guard-sessions"
SEPARATOR_RE = re.compile(r"&&|\|\||[;|]")


def find_git_invocation(command: str, subcommands: set[str]):
    for fragment in SEPARATOR_RE.split(command):
        try:
            tokens = shlex.split(fragment)
        except ValueError:
            continue
        if not tokens or tokens[0] != "git":
            continue
        i = 1
        repo_path = "."
        if i < len(tokens) and tokens[i] == "-C" and i + 1 < len(tokens):
            repo_path = tokens[i + 1]
            i += 2
        if i < len(tokens) and tokens[i] in subcommands:
            return repo_path, tokens[i]
    return None


def state_key(session_id: str, toplevel: str) -> Path:
    digest = hashlib.sha256(toplevel.encode()).hexdigest()[:16]
    return STATE_DIR / f"{session_id}__{digest}"


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
match = find_git_invocation(command, {"checkout", "switch"})
if not match:
    sys.exit(0)

repo_path, _ = match
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
    state_key(session_id, toplevel).write_text(actual)
except Exception:
    pass
