#!/usr/bin/env bash
# Normalize version frontmatter on skill files:
#   - ai/claude/skills/**/SKILL.md (version block + name, description, …)
#   - ai/claude/skills/**/references/*.md and **/examples/*.md (version block only)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRINCIPLES_VER="${PRINCIPLES_VER:-1.0.0}"
TODAY="${TODAY:-$(date +%Y-%m-%d)}"
UPDATED_BY="${UPDATED_BY:-human}"

export REPO_DIR PRINCIPLES_VER TODAY UPDATED_BY
python3 << 'PY'
import os
from pathlib import Path

repo = Path(os.environ["REPO_DIR"])
principles_ver = os.environ["PRINCIPLES_VER"]
today = os.environ["TODAY"]
updated_by = os.environ["UPDATED_BY"]

skills_root = repo / "ai" / "claude" / "skills"
if not skills_root.is_dir():
    print(f"error: {skills_root} not found — run make import-legacy first", flush=True)
    raise SystemExit(1)

VERSION_DEFAULTS = {
    "version": "1.0.0",
    "principles_version": principles_ver,
    "last_updated": today,
    "updated_by": updated_by,
}

VERSION_ORDER = ("version", "principles_version", "last_updated", "updated_by")
SKILL_ORDER = (
    "name",
    "description",
    "compatibility",
    "license",
    "metadata",
    "allowed-tools",
)


def parse_fm_line(line: str) -> tuple[str, str] | None:
    if ":" not in line:
        return None
    key, _, val = line.partition(":")
    return key.strip(), val.strip()


def parse_frontmatter(text: str) -> tuple[dict[str, str], str, bool]:
    if not text.startswith("---"):
        return {}, text, False
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text, False
    fm_text = text[3:end]
    body = text[end + 4 :]
    if body.startswith("\n"):
        body = body[1:]
    data: dict[str, str] = {}
    for line in fm_text.splitlines():
        parsed = parse_fm_line(line)
        if parsed:
            data[parsed[0]] = parsed[1]
    return data, body, True


def render_frontmatter(data: dict[str, str], *, skill: bool) -> str:
    lines: list[str] = []
    for key in VERSION_ORDER:
        if key in data:
            lines.append(f"{key}: {data[key]}")
    if skill:
        for key in SKILL_ORDER:
            if key in data:
                lines.append(f"{key}: {data[key]}")
    for key in sorted(data.keys()):
        if key not in VERSION_ORDER and key not in SKILL_ORDER:
            lines.append(f"{key}: {data[key]}")
    return "---\n" + "\n".join(lines) + "\n---\n\n"


def merge_version_defaults(data: dict[str, str]) -> dict[str, str]:
    merged = {**data}
    for k, v in VERSION_DEFAULTS.items():
        merged.setdefault(k, v)
    return merged


def normalize_skill(text: str) -> tuple[str, bool]:
    data, body, had_fm = parse_frontmatter(text)
    if not had_fm:
        data = {}
    merged = merge_version_defaults(data)
    if "name" not in merged:
        return text, False
    new_text = render_frontmatter(merged, skill=True) + body
    return new_text, new_text != text


def normalize_support(text: str) -> tuple[str, bool]:
    data, body, had_fm = parse_frontmatter(text)
    if not had_fm:
        data = {}
    # Keep only version keys + any extra keys after body merge
    merged = merge_version_defaults({k: v for k, v in data.items() if k in VERSION_ORDER})
    new_text = render_frontmatter(merged, skill=False) + body
    return new_text, new_text != text


count = 0
print("SKILL.md:")
for skill_md in sorted(skills_root.glob("*/SKILL.md")):
    raw = skill_md.read_text(encoding="utf-8")
    new, changed = normalize_skill(raw)
    if changed:
        skill_md.write_text(new, encoding="utf-8")
        print(f"  updated: {skill_md.relative_to(repo)}")
        count += 1
    else:
        print(f"  skip (ok): {skill_md.relative_to(repo)}")

print("\nreferences/ and examples/:")
for pattern in ("*/references/*.md", "*/examples/*.md"):
    for path in sorted(skills_root.glob(pattern)):
        raw = path.read_text(encoding="utf-8")
        new, changed = normalize_support(raw)
        if changed:
            path.write_text(new, encoding="utf-8")
            print(f"  updated: {path.relative_to(repo)}")
            count += 1
        else:
            print(f"  skip (ok): {path.relative_to(repo)}")

print(f"\nDone. {count} file(s) updated.")
PY
