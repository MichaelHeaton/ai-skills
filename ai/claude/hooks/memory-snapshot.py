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
failure can never block the user's actual edit."""
import json
import re
import subprocess
import sys
from pathlib import Path

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
    subprocess.run(
        ["git", "commit", "-m", f"auto-snapshot: {path.name}"],
        cwd=memory_dir,
        capture_output=True,
        check=False,
    )
except Exception:
    pass

sys.exit(0)
