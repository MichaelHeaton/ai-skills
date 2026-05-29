#!/usr/bin/env python3
"""Validate Tier A version frontmatter. See principles/versioning.md."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED = ("version", "principles_version", "last_updated", "updated_by")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
UPDATED_BY = frozenset({"human", "claude", "cursor"})


def parse_frontmatter(text: str) -> dict[str, str] | None:
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    data: dict[str, str] = {}
    for line in text[3:end].splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        data[key.strip()] = value.strip()
    return data


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    if fm is None:
        return [f"{path}: missing YAML frontmatter block"]

    for key in REQUIRED:
        if not fm.get(key):
            errors.append(f"{path}: missing required frontmatter key '{key}'")

    version = fm.get("version", "")
    if version and not SEMVER.match(version):
        errors.append(f"{path}: invalid version '{version}' (expected MAJOR.MINOR.PATCH)")

    principles_version = fm.get("principles_version", "")
    if principles_version and not SEMVER.match(principles_version):
        errors.append(
            f"{path}: invalid principles_version '{principles_version}' (expected MAJOR.MINOR.PATCH)"
        )

    last_updated = fm.get("last_updated", "")
    if last_updated and not DATE.match(last_updated):
        errors.append(f"{path}: invalid last_updated '{last_updated}' (expected YYYY-MM-DD)")

    updated_by = fm.get("updated_by", "")
    if updated_by and updated_by not in UPDATED_BY:
        errors.append(
            f"{path}: invalid updated_by '{updated_by}' (expected human, claude, or cursor)"
        )

    if path.suffix == ".mdc":
        if not fm.get("description"):
            errors.append(f"{path}: .mdc missing Cursor field 'description'")
        if "alwaysApply" not in fm and "globs" not in fm:
            errors.append(f"{path}: .mdc needs 'alwaysApply' or 'globs'")

    if path.name == "SKILL.md" and not fm.get("name"):
        errors.append(f"{path}: SKILL.md missing required frontmatter key 'name'")

    return errors


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    errors: list[str] = []
    for arg in sys.argv[1:]:
        path = Path(arg)
        if path.is_file():
            errors.extend(check_file(path))

    if errors:
        print("Tier A version frontmatter check failed:\n", file=sys.stderr)
        for err in errors:
            print(f"  {err}", file=sys.stderr)
        print("\nSee principles/versioning.md — run make bootstrap-version to fix.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
