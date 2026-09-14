#!/usr/bin/env python3
"""PostToolUse hook (Bash): updates branch-guard's recorded expectation
whenever this session explicitly runs `git checkout`/`git switch`, so a
deliberate branch change isn't flagged as a collision by branch-guard.py on
the next commit. Companion to branch-guard.py (PreToolUse). Never blocks.

Uses the same quote-aware, heredoc-aware, newline-splitting invocation
detection as branch-guard.py — see that file's docstring for the full
rationale (a `git checkout`/`git switch` on its own line after a
`cd <path>` line, with no `&&`/`;` joining them, was previously
undetected — the exact gap that let this hook's recorded expectation go
stale and made cursor-ide-commit-guard.py false-positive on a later
Edit/Write; correct POSIX quote-escape parity; heredoc bodies consumed
as one flushed span rather than split into fake fragments, including
excluding herestrings `<<<` and arithmetic `<<` from heredoc detection,
and queuing multiple heredocs opened on one line; and why a
backslash-newline line continuation is dropped rather than preserved)."""
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / ".branch-guard-sessions"
HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)(\w+)\1")


def _split_fragments(command: str) -> list[str]:
    """Split on &&/||/;/| and newlines, but never inside a quoted string, a
    heredoc body, a herestring, or arithmetic (( )) — and honoring
    backslash-newline line continuations."""
    fragments: list[str] = []
    current: list[str] = []
    quote: str | None = None
    arith_depth = 0
    i = 0
    n = len(command)
    while i < n:
        ch = command[i]

        if quote:
            current.append(ch)
            if quote == "'":
                if ch == "'":
                    quote = None
            elif ch == '"':
                backslashes = 0
                j = i - 1
                while j >= 0 and command[j] == "\\":
                    backslashes += 1
                    j -= 1
                if backslashes % 2 == 0:
                    quote = None
            i += 1
            continue

        if ch in ("'", '"'):
            quote = ch
            current.append(ch)
            i += 1
            continue

        if command[i:i + 3] == "<<<":
            current.append("<<<")
            i += 3
            continue

        if command[i:i + 2] == "((":
            arith_depth += 1
            current.append("((")
            i += 2
            continue
        if command[i:i + 2] == "))" and arith_depth > 0:
            arith_depth -= 1
            current.append("))")
            i += 2
            continue

        if arith_depth == 0 and command[i:i + 2] == "<<":
            line_end = command.find("\n", i)
            line_scan_end = line_end if line_end != -1 else n
            delims = []
            j = i
            while j < line_scan_end:
                if command[j:j + 2] == "<<" and command[j:j + 3] != "<<<":
                    dm = HEREDOC_RE.match(command, j)
                    if dm:
                        delims.append((dm.group(2), command[j:j + 3] == "<<-"))
                        j = dm.end()
                        continue
                j += 1
            if delims:
                if line_end == -1:
                    current.append(command[i:n])
                    i = n
                else:
                    current.append(command[i:line_end + 1])
                    i = line_end + 1
                for delim, strip_tabs in delims:
                    while i < n:
                        le = command.find("\n", i)
                        le_incl = le if le != -1 else n
                        line = command[i:le_incl]
                        check_line = line.lstrip("\t") if strip_tabs else line
                        current.append(line)
                        if le != -1:
                            current.append("\n")
                        if check_line == delim:
                            i = le + 1 if le != -1 else n
                            break
                        i = le + 1 if le != -1 else n
                fragments.append("".join(current))
                current = []
                continue

        if ch == "\\" and i + 1 < n and command[i + 1] == "\n":
            i += 2
            continue

        if ch == "\n":
            fragments.append("".join(current))
            current = []
            i += 1
            continue
        if command[i:i + 2] in ("&&", "||"):
            fragments.append("".join(current))
            current = []
            i += 2
            continue
        if ch in (";", "|"):
            fragments.append("".join(current))
            current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    fragments.append("".join(current))
    return fragments


def _tokenize(fragment: str) -> list[str]:
    try:
        return shlex.split(fragment)
    except ValueError:
        return fragment.split()


def find_git_invocation(command: str, subcommands: set[str]):
    for fragment in _split_fragments(command):
        tokens = _tokenize(fragment)
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
