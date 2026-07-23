#!/usr/bin/env python3
"""SessionStart hook: warn once every N hours if the local ai-skills checkout
is behind origin, or has other tracked drift, per `scripts/status.sh --json`.
Never blocks — always exits 0, and degrades silently if anything is missing."""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

THROTTLE_HOURS = float(os.environ.get("AI_SKILLS_SYNC_CHECK_HOURS", "6"))
FLAG = Path.home() / ".claude" / ".ai-skills-sync-check"

try:
    json.load(sys.stdin)  # consume/validate input; SessionStart payload unused
except Exception:
    pass

now = time.time()
try:
    last = float(FLAG.read_text().strip())
    if now - last < THROTTLE_HOURS * 3600:
        sys.exit(0)
except (FileNotFoundError, ValueError):
    pass


def find_repo():
    candidates = []
    env = os.environ.get("AI_SKILLS_REPO_DIR")
    if env:
        candidates.append(Path(env).expanduser())
    candidates.append(Path.home() / "Projects" / "personal" / "ai-skills")
    for c in candidates:
        if (c / ".git").is_dir() and (c / "scripts" / "status.sh").is_file():
            return c
    return None


repo = find_repo()
if repo is None:
    FLAG.write_text(str(now))
    sys.exit(0)  # not found on this machine — fail silently, no assumptions

try:
    result = subprocess.run(
        ["bash", str(repo / "scripts" / "status.sh"), "--json"],
        capture_output=True, text=True, timeout=12,
    )
    data = json.loads(result.stdout)
except Exception:
    FLAG.write_text(str(now))
    sys.exit(0)

FLAG.write_text(str(now))

clauses = []
git = data.get("git", {})
if git.get("checked") and (git.get("behind") or 0) > 0:
    clauses.append(f"{git['behind']} commit(s) behind origin")
rvs = data.get("repo_vs_system", {})
if rvs.get("pending_links"):
    clauses.append(f"{rvs['pending_links']} item(s) undeployed to ~/.claude")
stale = data.get("desktop_upload", {}).get("stale_skills") or []
if stale:
    clauses.append(f"{len(stale)} skill(s) need Desktop/claude.ai re-upload")
behind_targets = data.get("push_targets", {}).get("behind") or []
if behind_targets:
    clauses.append(f"{len(behind_targets)} push-skills target(s) behind")

if clauses:
    print(f"[ai-skills] {'; '.join(clauses)} — run 'make status' in {repo}")
