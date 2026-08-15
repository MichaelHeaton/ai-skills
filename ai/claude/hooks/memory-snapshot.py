#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): auto-snapshot writes to a project's
memory/*.md files (~/.claude/projects/<project-hash>/memory/*.md), written
directly by Claude per the global CLAUDE.md "auto memory" instructions and
not tracked by any named skill or git repo today. Inits a local git repo in
the memory directory if none exists yet, then commits the change as
`auto-snapshot: <filename>` so a bad edit can be rolled back later via the
memory-rollback skill.

NOT wired into any tracked settings.json by default — this hook is opt-in.
Enable it via the `update-config` skill, matching the existing precedent at
ai/claude/hooks/skill-review-reminder.py.

Advisory only: always exits 0, all logic wrapped in try/except, so a hook
failure can never block the user's actual edit. A failed commit (e.g. no
resolvable git identity) is still non-blocking, but is logged to
.memory-snapshot.log in the memory dir instead of failing silently — a
rollback tool that can lose its one job with zero signal defeats the point
of having it."""
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def _log_failure(memory_dir: Path, filename: str, output: str) -> None:
    reason = output.strip().splitlines()[-1] if output.strip() else "unknown error"
    timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with open(memory_dir / ".memory-snapshot.log", "a") as f:
        f.write(f"{timestamp} FAILED to snapshot {filename}: {reason}\n")


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

try:
    file_path = str(data.get("tool_input", {}).get("file_path", ""))
    if not file_path:
        sys.exit(0)

    path = Path(file_path)

    # Match anything under ~/.claude/projects/*/memory/*.md
    if not re.search(r"/\.claude/projects/[^/]+/memory/[^/]+\.md$", str(path)):
        sys.exit(0)

    if not path.is_file():
        sys.exit(0)

    memory_dir = path.parent

    # Init a local git repo in the memory dir if none exists yet.
    if not (memory_dir / ".git").is_dir():
        subprocess.run(
            ["git", "init"],
            cwd=memory_dir,
            capture_output=True,
            check=False,
        )

    subprocess.run(
        ["git", "add", path.name],
        cwd=memory_dir,
        capture_output=True,
        check=False,
    )
    commit_result = subprocess.run(
        ["git", "commit", "-m", f"auto-snapshot: {path.name}"],
        cwd=memory_dir,
        capture_output=True,
        check=False,
    )

    if commit_result.returncode != 0:
        stdout = commit_result.stdout.decode("utf-8", "replace")
        stderr = commit_result.stderr.decode("utf-8", "replace")
        # git writes "nothing to commit" to STDOUT, not stderr - the content
        # didn't actually change (e.g. a re-save with identical content),
        # not a real failure. Check both so a real failure is never missed.
        if "nothing to commit" not in (stdout + stderr).lower():
            _log_failure(memory_dir, path.name, stderr or stdout)
except Exception:
    pass

sys.exit(0)
