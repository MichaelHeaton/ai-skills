#!/usr/bin/env bash
# Detect whether the active branch in a shared (non-worktree) checkout has
# changed out from under this session — e.g. another process shares this
# exact checkout and switched branches. Distinct from
# session-close/scripts/check-concurrent-session.sh, which only detects that
# another live process exists, not that it swapped the branch under a
# shared checkout — a second live process in an isolated worktree is
# harmless; a second process silently switching branches on this same
# non-worktree checkout is a real commit-to-the-wrong-branch risk.
#
# Usage: check-branch-identity.sh <repo-path> <expected-branch>
# Output: MATCH              — active branch matches what this session expects
#         MISMATCH:<actual>  — active branch differs in a shared checkout; real collision risk
#         WORKTREE:<actual>  — this checkout is an isolated worktree; a branch swap in a
#                              different checkout of the same repo can't collide with it here
# Exits 0 always — this is advisory, never a hard gate.

REPO="$1"
EXPECTED="$2"
[[ -z "$REPO" || -z "$EXPECTED" ]] && { echo "usage: check-branch-identity.sh <repo-path> <expected-branch>" >&2; exit 0; }

TOPLEVEL=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
[[ -z "$TOPLEVEL" ]] && exit 0

ACTUAL=$(git -C "$REPO" branch --show-current 2>/dev/null)
[[ -z "$ACTUAL" ]] && exit 0

if [[ "$ACTUAL" == "$EXPECTED" ]]; then
  echo "MATCH"
  exit 0
fi

# In a regular checkout, .git is a directory. In an isolated `git worktree`
# checkout, .git is a file containing "gitdir: <path-to-.git/worktrees/name>"
# — that file form is what tells the two cases apart.
if [[ -f "$TOPLEVEL/.git" ]]; then
  echo "WORKTREE:${ACTUAL}"
else
  echo "MISMATCH:${ACTUAL}"
fi
