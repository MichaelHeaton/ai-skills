#!/usr/bin/env bash
# Regenerate .deploy/repo-manifest.json (MD5 of deployable paths).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_DIR/.deploy/repo-manifest.json"
TODAY="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$REPO_DIR/.deploy"

export REPO_DIR TODAY
python3 << PY
import hashlib
import json
import os
from pathlib import Path

repo = Path(os.environ["REPO_DIR"])
paths = {}

def add_file(p: Path):
    rel = p.relative_to(repo).as_posix()
    h = hashlib.md5(p.read_bytes()).hexdigest()
    paths[rel] = h

# Universal layer (always tracked)
principles = repo / "principles"
if principles.is_dir():
    for f in sorted(principles.glob("*.md")):
        add_file(f)

# Claude deploy tree (after import-legacy)
claude = repo / "ai" / "claude"
if claude.is_dir():
    for sub in ("skills", "hooks", "memory"):
        root = claude / sub
        if not root.is_dir():
            continue
        for f in sorted(root.rglob("*")):
            if f.is_file() and ".git" not in f.parts and "__pycache__" not in f.parts and f.suffix != ".pyc":
                add_file(f)
    cm = claude / "CLAUDE.md"
    if cm.is_file():
        add_file(cm)

cursor_rules = repo / "ai" / "cursor" / "rules"
if cursor_rules.is_dir():
    for f in sorted(cursor_rules.glob("*.mdc")):
        add_file(f)

scope_parts = []
if principles.is_dir():
    scope_parts.append("principles")
if (repo / "ai" / "claude").is_dir():
    scope_parts.append("ai/claude")
if cursor_rules.is_dir() and any(cursor_rules.glob("*.mdc")):
    scope_parts.append("ai/cursor/rules")
scope = "+".join(scope_parts) if scope_parts else "empty"

out = {
    "generated_at": os.environ["TODAY"],
    "algorithm": "md5",
    "scope": scope,
    "paths": dict(sorted(paths.items())),
}

manifest = repo / ".deploy" / "repo-manifest.json"
manifest.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(paths)} paths ({scope}) → {manifest.relative_to(repo)}")
PY
