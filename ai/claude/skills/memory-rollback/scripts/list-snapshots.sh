#!/usr/bin/env bash
# List git snapshot commits for a single file inside a memory directory's
# local git repo (created by ai/claude/hooks/memory-snapshot.py). Lets the
# memory-rollback skill show the user what's available before restoring one.
#
# Usage: list-snapshots.sh <memory-dir> <filename>
# Output: <rev>:<iso-date>:<subject>  (newest first)
# Exits 0 always — this is advisory, not a hard gate.

MEMORY_DIR="$1"
FILENAME="$2"

if [[ -z "$MEMORY_DIR" || -z "$FILENAME" ]]; then
  echo "usage: list-snapshots.sh <memory-dir> <filename>" >&2
  exit 0
fi

[[ -d "$MEMORY_DIR" ]] || { echo "no such directory: $MEMORY_DIR" >&2; exit 0; }
[[ -f "$MEMORY_DIR/$FILENAME" ]] || { echo "no such file: $MEMORY_DIR/$FILENAME" >&2; exit 0; }

# ".git" can exist with zero commits if init succeeded but the first commit
# failed (e.g. no resolvable git identity) — check for a real commit, not
# just the directory, so both cases report the same clean message.
if [[ ! -d "$MEMORY_DIR/.git" ]] || ! git -C "$MEMORY_DIR" rev-parse HEAD >/dev/null 2>&1; then
  echo "no snapshots yet" >&2
  exit 0
fi

git -C "$MEMORY_DIR" log --follow --date=iso-strict \
  --pretty=format:'%h:%ad:%s' -- "$FILENAME"
echo
