#!/usr/bin/env python3
"""Validate SKILL.md frontmatter conventions. See docs/guides/skill-conventions.md.

Complementary to check-tier-a-version.py, which already validates required-field
presence (version/principles_version/last_updated/updated_by/name) and the
version/date format. This check does NOT re-validate field presence -- it only
covers the two constraints Tier A doesn't: the name-matches-directory rule, and
the description length cap.

GRANDFATHERED, WITH A FROZEN CEILING: a handful of skills already exceeded the
description length cap from before this check existed. Enforcing the cap
retroactively on every future edit to those files (even a one-line, unrelated
change) would block ordinary maintenance with no migration path -- but an
unbounded exemption would let exactly those already-over-length files grow
without limit forever, which defeats the point of having a cap at all. Each
grandfathered skill's ceiling is frozen at its own length when this check was
introduced (2026-09-12, recorded in LENGTH_EXEMPT_CEILING below) -- the file
can shrink freely, or hold steady, but can't grow past that frozen number.
Trim under DESCRIPTION_MAX_CHARS and remove from this dict entirely rather
than adding a new name here; a non-exempt skill is enforced against
DESCRIPTION_MAX_CHARS from this check's introduction onward, so this dict
closes rather than grows.
"""
from __future__ import annotations

import sys
from pathlib import Path

DESCRIPTION_MAX_CHARS = 1024

# Skills whose description already exceeded DESCRIPTION_MAX_CHARS when this
# check was introduced (2026-09-12), mapped to their exact length at that
# time -- the frozen ceiling those files may not grow past. Trim under
# DESCRIPTION_MAX_CHARS and remove the entry rather than raising the number.
LENGTH_EXEMPT_CEILING = {
    "confluence-section-edit": 1141,
    "contextual-pr-review": 1193,
    "iac-plan-verify": 1056,
    "infra-rehearsal-session": 1148,
    "infra-state-verify": 1589,
    "issue-create": 1063,
    "issue-update": 1412,
    "skill-session-handoff": 1045,
    "vault-support": 1184,
}


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

    name = fm.get("name", "")
    if name:
        dir_name = path.parent.name
        if name != dir_name:
            errors.append(
                f"{path}: frontmatter 'name' ({name!r}) does not match directory name ({dir_name!r})"
            )

    description = fm.get("description", "")
    if description:
        limit = LENGTH_EXEMPT_CEILING.get(name, DESCRIPTION_MAX_CHARS)
        if len(description) > limit:
            if name in LENGTH_EXEMPT_CEILING:
                errors.append(
                    f"{path}: description is {len(description)} chars, exceeds this "
                    f"skill's frozen grandfather ceiling of {limit} chars (set at "
                    f"introduction of this check -- shrink it, don't grow it further; "
                    f"see docs/guides/skill-conventions.md)"
                )
            else:
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
