#!/usr/bin/env python3
"""PreToolUse hook (Edit|Write): blocks a file edit when the active branch in
a shared (non-worktree) checkout has drifted from this session's recorded
expectation AND the working tree is dirty — catches a Cursor-IDE user-
initiated branch switch (via the sidebar, not any agent tool call) landing
an Edit/Write on the wrong branch, or discarding uncommitted work, before
the next `git commit` would have caught it.

Complements, does not duplicate, branch-guard.py (PreToolUse, matcher
`Bash`), which fires only on `git commit` and only detects a second
*process* swapping the branch. Neither branch-guard.py nor
branch-guard-track.py observes anything outside a `Bash` tool call, so a
branch switch made entirely through Cursor's IDE sidebar (no Bash git
invocation at all) is invisible to both until the next `git commit` attempt
— this hook closes that gap by checking at Edit/Write time instead, the
narrower and earlier-firing case documented in git-ops/SKILL.md's "Cursor
IDE branch switches" subsection.

Reuses branch-guard-track.py's own state file (~/.claude/.branch-guard-sessions/
<session_id>__<sha256(toplevel)[:16]>) as the single source of truth for
"what branch does this session expect" — never writes its own separate
expectation, since branch-guard-track.py already updates that file whenever
this session explicitly runs `git checkout`/`git switch` via Bash.

Fails open (allows) whenever it can't confidently detect drift: not a git
repo, a worktree checkout (branch is pinned, can't collide), a detached
HEAD, or no recorded expectation yet (nothing to compare against on the
first edit of a session). Fails CLOSED (blocks) if a mismatch is found but
the dirty-tree check itself errors — an unreadable working-tree state is
exactly the uncertainty this hook exists to catch, not a reason to wave the
edit through."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / ".branch-guard-sessions"


def state_key(session_id: str, toplevel: str) -> Path:
    digest = hashlib.sha256(toplevel.encode()).hexdigest()[:16]
    return STATE_DIR / f"{session_id}__{digest}"


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
file_path = str(tool_input.get("file_path", ""))
if not file_path:
    sys.exit(0)

target = Path(file_path)
if not target.is_absolute():
    cwd = data.get("cwd") or "."
    target = Path(cwd) / target
start_dir = str(target.parent)

try:
    toplevel = subprocess.run(
        ["git", "-C", start_dir, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)
if not toplevel:
    sys.exit(0)  # not inside a git repo

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

session_id = data.get("session_id") or "unknown"
state_file = state_key(session_id, toplevel)
if not state_file.exists():
    sys.exit(0)  # no recorded expectation yet (first edit this session)

expected = state_file.read_text().strip()
if expected == actual:
    sys.exit(0)  # matches this session's own last-known branch — no drift

try:
    status = subprocess.run(
        ["git", "-C", toplevel, "status", "--short"],
        capture_output=True, text=True, timeout=5,
    )
    dirty = bool(status.stdout.strip())
    status_failed = status.returncode != 0
except Exception:
    dirty = True  # can't confirm clean — fail closed on a real branch mismatch
    status_failed = True

if not dirty and not status_failed:
    sys.exit(0)  # branch drifted but tree is clean — nothing to lose, allow

print(
    f"BLOCKED: this session expected branch '{expected}' in {toplevel}, but "
    f"'{actual}' is checked out now and the working tree is dirty — likely "
    "an IDE-driven branch switch (e.g. Cursor's sidebar) out from under this "
    "session, not an agent-initiated checkout. Stop before editing further.\n"
    "Recover per git-ops/SKILL.md's Cursor-IDE branch-switch subsection:\n"
    f"  git log {expected} --oneline -5   # see what was left on the previous branch\n"
    f"  git diff {expected}               # inspect uncommitted work that may be stranded\n"
    "Then cherry-pick or manually reapply anything that needs to move to the "
    "current branch before making any further edits.",
    file=sys.stderr,
)
sys.exit(2)
