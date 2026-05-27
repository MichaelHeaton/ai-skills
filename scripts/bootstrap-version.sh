#!/usr/bin/env bash
# Add Tier A version frontmatter to ai/claude/skills/**/SKILL.md when missing.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRINCIPLES_VER="${PRINCIPLES_VER:-1.0.0}"
TODAY="${TODAY:-$(date +%Y-%m-%d)}"
UPDATED_BY="${UPDATED_BY:-human}"

export REPO_DIR PRINCIPLES_VER TODAY UPDATED_BY
python3 << 'PY'
import os
import re
from pathlib import Path

repo = Path(os.environ["REPO_DIR"])
principles_ver = os.environ["PRINCIPLES_VER"]
today = os.environ["TODAY"]
updated_by = os.environ["UPDATED_BY"]

skills_root = repo / "ai" / "claude" / "skills"
if not skills_root.is_dir():
    print(f"error: {skills_root} not found — run make import-legacy first", flush=True)
    raise SystemExit(1)

fields = {
    "version": "1.0.0",
    "principles_version": principles_ver,
    "last_updated": today,
    "updated_by": updated_by,
}

def patch_frontmatter(text: str) -> tuple[str, bool]:
    if not text.startswith("---"):
        new = "---\n"
        for k, v in fields.items():
            new += f"{k}: {v}\n"
        new += "---\n\n" + text
        return new, True
    end = text.find("\n---", 3)
    if end == -1:
        return text, False
    fm = text[3:end]
    body = text[end + 4 :]
    if body.startswith("\n"):
        body = body[1:]
    lines = fm.splitlines()
    keys = {line.split(":", 1)[0].strip() for line in lines if ":" in line}
    changed = False
    for k, v in fields.items():
        if k not in keys:
            lines.append(f"{k}: {v}")
            changed = True
    if not changed:
        return text, False
    new_fm = "---\n" + "\n".join(lines) + "\n---\n\n" + body
    return new_fm, True

count = 0
for skill_md in sorted(skills_root.glob("*/SKILL.md")):
    raw = skill_md.read_text(encoding="utf-8")
    new, changed = patch_frontmatter(raw)
    if changed:
        skill_md.write_text(new, encoding="utf-8")
        print(f"  updated: {skill_md.relative_to(repo)}")
        count += 1
    else:
        print(f"  skip (ok): {skill_md.relative_to(repo)}")

print(f"\nDone. {count} file(s) updated.")
PY
