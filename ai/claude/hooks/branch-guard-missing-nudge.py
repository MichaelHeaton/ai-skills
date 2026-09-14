#!/usr/bin/env python3
"""PreToolUse hook (Bash): nudge, once per repo per session, when the repo
about to receive a `git commit` doesn't have branch-guard.py wired at all —
neither in its own .claude/settings.json nor in the global
~/.claude/settings.json, or the hook script itself is missing from disk.
Advisory only — always exits 0, never blocks the commit. Mechanizes
git-ops's "One-time nudge when the guard is missing entirely" section
instead of leaving it as a prose-only instruction to remember.

Stdout must be empty or valid JSON: Cursor PreToolUse rejects plain-text
nudge lines as invalid JSON and blocks the tool call.

Uses the same quote-aware, heredoc-aware, newline-splitting invocation
detection as branch-guard.py and branch-guard-track.py — see
branch-guard.py's docstring for the full rationale (a `git commit` on its
own line after a `cd <path>` line was previously undetected; a naive
newline split alone would misparse a multi-line quoted argument or a
heredoc body as a fake invocation; POSIX quote-escape parity matters for
strings ending in a backslash; heredoc bodies are consumed as one flushed
span rather than split into fake fragments, including excluding
herestrings `<<<` and arithmetic `<<` from heredoc detection, and
queuing multiple heredocs opened on one line; a backslash-newline line
continuation has to be dropped, not preserved, since shlex.split doesn't
elide it itself). This hook never blocks, so a missed or
spuriously-detected commit here only means a missing (or extra) advisory
nudge, not an incorrect allow/deny — lower stakes than the other two
hooks, but kept in sync with them so all three copies of this parser
behave identically rather than silently diverging."""
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / ".branch-guard-missing-sessions"
GLOBAL_HOOK_PATH = Path.home() / ".claude" / "hooks" / "branch-guard.py"
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


def find_commit_invocation(command: str):
    for fragment in _split_fragments(command):
        tokens = _tokenize(fragment)
        if not tokens or tokens[0] != "git":
            continue
        i = 1
        repo_path = "."
        if i < len(tokens) and tokens[i] == "-C" and i + 1 < len(tokens):
            repo_path = tokens[i + 1]
            i += 2
        if i < len(tokens) and tokens[i] == "commit":
            return repo_path
    return None


def wires_branch_guard(settings_path: Path) -> bool:
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        return False
    pre_tool_use = (settings.get("hooks", {}) or {}).get("PreToolUse", []) or []
    for entry in pre_tool_use:
        for hook in entry.get("hooks", []) or []:
            if "branch-guard.py" in str(hook.get("command", "")):
                return True
    return False


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = str((data.get("tool_input", {}) or {}).get("command", ""))
repo_path = find_commit_invocation(command)
if repo_path is None:
    sys.exit(0)

try:
    toplevel = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not toplevel:
    sys.exit(0)

session_id = data.get("session_id") or "unknown"
digest = hashlib.sha256(toplevel.encode()).hexdigest()[:16]
flag_path = STATE_DIR / f"{session_id}__{digest}"
if flag_path.exists():
    sys.exit(0)

repo_settings = Path(toplevel) / ".claude" / "settings.json"
global_settings = Path.home() / ".claude" / "settings.json"

wired = (
    (repo_settings.exists() and wires_branch_guard(repo_settings))
    or (global_settings.exists() and wires_branch_guard(global_settings))
)
hook_script_present = GLOBAL_HOOK_PATH.exists()

if wired and hook_script_present:
    sys.exit(0)

flag_path.parent.mkdir(parents=True, exist_ok=True)
flag_path.touch()

msg = (
    "[branch-guard] This repo doesn't have branch-guard.py wired (checked "
    f"{repo_settings} and {global_settings}), or the hook script itself is "
    "missing from ~/.claude/hooks/ — a second process silently swapping "
    "the active branch in a shared checkout wouldn't be caught here. "
    "Install it via the update-config skill (see git-ops's 'Shared "
    "checkout branch-identity check' section for the JSON block) if this "
    "repo uses a shared, non-worktree checkout."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}))
