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
its branch is pinned to that worktree — so this always allows worktrees.

Detects the actual `git ... commit` invocation by tokenizing each
shell-separator-delimited fragment of the command with shlex, rather than
substring-matching "git commit" anywhere in the raw text — a substring
match false-positives on something like `echo about to run git commit
later` and can't tell a real invocation from one mentioned inside a quoted
argument (`git log --grep='git commit'`).

Fragments split on newlines as well as `&&`/`||`/`;`/`|`, since a `git`
invocation is a separate logical command on its own line even with no
shell metacharacter joining it to the line before (e.g. a `cd <path>`
line followed by `git commit ...` on the next line) — the original
separator set missed this, silently failing to detect the commit whenever
it wasn't the first line of a multi-line script.

The split is quote-aware (tracks single/double-quote depth char-by-char,
with correct POSIX escape rules — single quotes have no escape mechanism
at all, double quotes close on an even count of preceding backslashes)
so it never splits inside a quoted string. A naive first version got this
wrong (one-character backslash lookback, no parity check), which silently
absorbed a real `&&`-joined git invocation whenever it followed a
single-quoted string ending in a backslash, or a double-quoted string
ending in an escaped backslash — caught in review before landing.

Heredoc bodies (`<<EOF`, `<<'EOF'`, `<<-EOF`, ...) are detected and
consumed as an atomic span, ending the current fragment at the
terminating delimiter line rather than letting whatever follows glue onto
it — a naive quote-tracker treats `<<'EOF'` as an ordinary quote that
closes immediately after the delimiter, leaving the heredoc BODY as bare
unquoted text on its own fragment (a fail-open: a doc file's heredoc'd
example command would then read as a genuine invocation, and for
branch-guard-track.py specifically, silently overwrite a correct stale
expectation with the wrong branch — the exact collision this hook pair
exists to catch). An earlier version of this fix consumed the heredoc
span correctly but never flushed the accumulated fragment afterward, so
everything AFTER the heredoc (including a real `git commit` two lines
later) silently glued onto the heredoc's own fragment and went
undetected — caught in review, fixed by flushing immediately once the
terminator is found. All heredoc markers opened on the same physical
line are scanned and queued up front, then consumed in that order, so
`cmd1 <<A; cmd2 <<B` on one line doesn't leave B's body to be
misinterpreted as ordinary (and possibly matching) shell text once A's
span ends.

A herestring (`<<<`) is not a heredoc and is left as ordinary text —
without this exclusion the second `<` of `<<<` gets re-examined as a
fresh heredoc-marker start on the next loop iteration and can swallow the
rest of the command. Similarly, `<<` inside `((...))`/`$((...))`
arithmetic is a bitshift operator, not a redirect, and is excluded via a
paren-depth counter — otherwise something like `$((1<<2))` reads as a
heredoc opener with delimiter `2` and swallows everything after it,
including a real `&&`-joined git invocation. Both were caught in review
as regressions against the pre-fix behavior.

A backslash immediately followed by a newline, outside any quote or
heredoc, is a shell line continuation — the pair is dropped entirely
(joining the two physical lines) rather than left in the fragment text,
since `shlex.split` does not perform this joining itself (it turns a bare
backslash-newline into a literal standalone newline token instead of
eliding it, which would silently break a `git commit` invocation split
across two lines with a trailing continuation backslash).

A fragment that still fails to shlex-tokenize after all of the above
falls back to plain whitespace splitting — sufficient since only the
first few tokens (`git`, optional `-C <path>`, subcommand) are ever
inspected, always before any quoted argument value."""
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
                # heredoc terminator lines are always alone on their own
                # line, so whatever follows starts a fresh fragment
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
    """Return (repo_path, subcommand) for the first fragment whose first
    token is literally `git` and whose next real token (after an optional
    `-C <path>`) is one of `subcommands`. None if nothing matches."""
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
match = find_git_invocation(command, {"commit"})
if not match:
    sys.exit(0)

repo_path, _ = match
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
    sys.exit(0)  # detached HEAD — no branch name to compare against

state_file = state_key(session_id, toplevel)
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
