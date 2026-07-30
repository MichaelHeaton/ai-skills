#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): nudge to create a tracking issue when a new
homebrew cask/formula/MAS entry is added to group_vars/{all,work,personal}.yml,
so its chezmoi config never gets forgotten. Never blocks, degrades silently."""
import json
import re
import subprocess
import sys
from pathlib import Path

WATCHED_FILES = (
    "group_vars/all.yml",
    "group_vars/work.yml",
    "group_vars/personal.yml",
)

WATCHED_KEYS = {
    "homebrew_casks_common",
    "homebrew_casks_profile",
    "homebrew_formulae_common",
    "homebrew_formulae_profile",
    "homebrew_mas_apps",
}

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

file_path = data.get("tool_input", {}).get("file_path", "")
if not file_path or not file_path.endswith(WATCHED_FILES):
    sys.exit(0)


def find_repo_root(path: str):
    try:
        p = Path(path).resolve()
        d = p.parent if p.suffix or p.is_file() else p
        while True:
            if (d / ".git").exists():
                return d
            if d.parent == d:
                break
            d = d.parent
    except Exception:
        pass

    try:
        result = subprocess.run(
            ["git", "-C", str(Path(path).resolve().parent), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            root = result.stdout.strip()
            if root:
                return Path(root)
    except Exception:
        pass

    return None


try:
    repo_root = find_repo_root(file_path)
    if repo_root is None:
        sys.exit(0)

    abs_path = Path(file_path).resolve()
    try:
        rel_path = abs_path.relative_to(repo_root)
    except ValueError:
        sys.exit(0)

    # Use -U0 (no context lines) and derive real new-file line numbers from
    # the hunk headers, rather than relying on diff context to reveal the
    # enclosing top-level key. A watched key can easily be declared more than
    # a few lines above where a new entry is appended to an already-populated
    # list, so context-based key tracking silently misses exactly the common
    # case of "append to an existing list" — see ticket #22 discussion.
    result = subprocess.run(
        ["git", "-C", str(repo_root), "diff", "--unified=0", "HEAD", "--", str(rel_path)],
        capture_output=True, text=True, timeout=10,
    )
    diff_output = result.stdout
    if not diff_output:
        sys.exit(0)

    hunk_header_re = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")
    list_item_re = re.compile(r"^\+\s*-\s*(.+)$")
    top_level_key_re = re.compile(r"^(\S[^:]*):\s*(#.*)?$")

    added_lines = []  # list of (new_file_line_no, raw_added_text)
    new_file_line_no = None

    for line in diff_output.splitlines():
        if line.startswith("+++") or line.startswith("---"):
            continue
        hunk_match = hunk_header_re.match(line)
        if hunk_match:
            new_file_line_no = int(hunk_match.group(1))
            continue
        if new_file_line_no is None:
            continue
        if line.startswith("+"):
            added_lines.append((new_file_line_no, line))
            new_file_line_no += 1
        # deletion ("-") lines don't occupy a new-file line number, so the
        # counter is left unchanged for them.

    if not added_lines:
        sys.exit(0)

    # Read the actual current file content so we can scan backward from each
    # added line's real position to find its enclosing top-level key,
    # regardless of how far above it that key was declared.
    file_lines = Path(file_path).read_text().splitlines()

    new_entries = []
    for line_no, raw_line in added_lines:
        item_match = list_item_re.match(raw_line)
        if not item_match:
            continue

        current_key = None
        for idx in range(line_no - 2, -1, -1):  # line_no is 1-indexed
            if idx >= len(file_lines):
                continue
            candidate = file_lines[idx]
            if not candidate or candidate[0].isspace():
                continue
            key_match = top_level_key_re.match(candidate)
            if key_match:
                current_key = key_match.group(1).strip()
                break

        if current_key not in WATCHED_KEYS:
            continue

        raw = item_match.group(1).strip()
        # Handle MAS-style "- id: 12345" / "- name: Foo" entries and
        # plain "- foo-cask" entries alike; over-match rather than miss.
        name_match = re.search(r"(?:name|id)\s*:\s*(.+)", raw)
        name = name_match.group(1).strip() if name_match else raw
        name = name.strip("'\"")
        if name:
            new_entries.append((name, current_key))

    if new_entries:
        for name, key in new_entries:
            print(
                f'[config-capture] New homebrew entry detected: {name} (key: {key}, file: {file_path}) '
                f'— create a tracking issue via the issue-create skill, titled '
                f'"chore: capture and sync {name} config files via chezmoi".'
            )
except Exception:
    sys.exit(0)
