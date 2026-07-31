#!/usr/bin/env python3
"""
cli-filter — print the most recent filtered log(s) for a tool from clog

Usage: cli-filter <tool> [-n N | --last N]

Reads from ~/.claude/logs/ (or $CLI_FILTER_LOG_DIR if set, for testing),
which is populated by `clog` (see log-clip skill). Prints the newest N
filtered logs for the given tool, most recent first.
"""

import argparse
import os
import sys
from pathlib import Path


def get_log_dir() -> Path:
    override = os.environ.get("CLI_FILTER_LOG_DIR")
    if override:
        return Path(override)
    return Path.home() / ".claude" / "logs"


def find_logs(log_dir: Path, tool: str) -> list[Path]:
    if not log_dir.is_dir():
        return []
    matches = [
        p
        for p in log_dir.glob(f"{tool}-*.log")
        if p.is_file() and not p.name.startswith(".")
    ]
    matches.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return matches


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cli-filter",
        description="Print the most recent filtered log(s) for a tool from ~/.claude/logs/",
    )
    parser.add_argument("tool", help="tool name, e.g. tf, ansible, vault, k8s")
    parser.add_argument(
        "-n",
        "--last",
        type=int,
        default=1,
        metavar="N",
        help="number of most recent logs to print (default: 1)",
    )
    args = parser.parse_args()

    log_dir = get_log_dir()
    tool = args.tool
    matches = find_logs(log_dir, tool)

    if not matches:
        print(
            f"cli-filter: no filtered logs found for tool '{tool}' in {log_dir}",
            file=sys.stderr,
        )
        return 1

    selected = matches[: args.last]

    if len(selected) == 1 and args.last == 1:
        print(selected[0].read_text(), end="")
    else:
        for path in selected:
            print(f"=== {path.name} ===")
            print(path.read_text())

    return 0


if __name__ == "__main__":
    sys.exit(main())
