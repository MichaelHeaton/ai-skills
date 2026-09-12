#!/usr/bin/env python3
"""Validate SKILL.md frontmatter conventions. See docs/guides/skill-conventions.md.

Complementary to check-tier-a-version.py (which validates version/date/updated_by
formats). This check focuses on the fields and constraints specific to skill
authoring: required-field presence, the name-matches-directory rule, and the
description length cap.
"""
from __future__ import annotations

import sys
from pathlib import Path

REQUIRED = ("version", "principles_version", "last_updated", "updated_by", "name", "description")
DESCRIPTION_MAX_CHARS = 1024


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

    name = fm.get("name", "")
    if name:
        dir_name = path.parent.name
        if name != dir_name:
            errors.append(
                f"{path}: frontmatter 'name' ({name!r}) does not match directory name ({dir_name!r})"
            )

    description = fm.get("description", "")
    if description and len(description) > DESCRIPTION_MAX_CHARS:
        errors.append(
            f"{path}: description is {len(description)} chars, exceeds max of "
            f"{DESCRIPTION_MAX_CHARS} (see docs/guides/skill-conventions.md)"
        )

    return errors


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    errors: list[str] = []
    for arg in sys.argv[1:]:
        path = Path(arg)
        if path.is_file() and path.name == "SKILL.md":
            errors.extend(check_file(path))

    if errors:
        print("SKILL.md frontmatter lint failed:\n", file=sys.stderr)
        for err in errors:
            print(f"  {err}", file=sys.stderr)
        print(
            "\nSee docs/guides/skill-conventions.md for required frontmatter fields.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
