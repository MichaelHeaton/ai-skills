#!/usr/bin/env bash
# Regenerate .deploy/repo-manifest.json (MD5 of deployable paths).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_DIR/.deploy/repo-manifest.json"
TODAY="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$REPO_DIR/.deploy"

python3 << PY
import hashlib
import json
from pathlib import Path

repo = Path("$REPO_DIR")
paths = {}

def add_file(p: Path):
    rel = p.relative_to(repo).as_posix()
    h = hashlib.md5(p.read_bytes()).hexdigest()
    paths[rel] = h

# Claude deploy tree
claude = repo / "ai" / "claude"
if claude.is_dir():
    for sub in ("skills", "hooks", "memory"):
        root = claude / sub
        if not root.is_dir():
            continue
        for f in sorted(root.rglob("*")):
            if f.is_file() and ".git" not in f.parts:
                add_file(f)
    cm = claude / "CLAUDE.md"
    if cm.is_file():
        add_file(cm)

out = {
    "generated_at": "$TODAY",
    "algorithm": "md5",
    "paths": dict(sorted(paths.items())),
}

manifest = repo / ".deploy" / "repo-manifest.json"
manifest.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(paths)} paths → {manifest.relative_to(repo)}")
PY
