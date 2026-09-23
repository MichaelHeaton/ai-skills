#!/usr/bin/env bash
# Identify and delete local branches whose remote tracking ref is gone, without
# the false-negative session-close's inline pipeline has: `git branch -d`'s
# ancestor check fails on a squash-merged branch even though its content
# genuinely landed on main, so those branches pile up across sessions instead
# of getting cleaned up (see git-ops issue #871). This script adds the
# `git cherry` content check the plain `-vv | grep gone | xargs branch -d`
# pipeline is missing, so squash-merged branches are correctly recognized as
# safe while branches with real unmerged commits are correctly excluded.
#
# Usage: prune-branches.sh [repo-path] [--yes|-y]
#   repo-path — defaults to the current working directory
#   --yes/-y  — skip the interactive confirmation and delete immediately
#
# Output: a labeled "safe to delete" list (with count), a separate
# "NOT SAFE (unmerged commits found via git cherry): <branch>" line for each
# excluded branch, then either the confirm prompt or (with --yes) the delete
# results.
# Exits 0 on success (including "nothing to do"), 1 on usage error.

set -euo pipefail

REPO="."
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    --yes|-y)
      ASSUME_YES=1
      ;;
    -*)
      echo "usage: prune-branches.sh [repo-path] [--yes|-y]" >&2
      exit 1
      ;;
    *)
      REPO="$arg"
      ;;
  esac
done

TOPLEVEL=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: '$REPO' is not a git repository" >&2
  exit 1
}

# Sync gone-branch state before reading it.
git -C "$TOPLEVEL" fetch --prune origin >/dev/null 2>&1 || true

MAIN_BRANCH=$(git -C "$TOPLEVEL" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
[[ -z "$MAIN_BRANCH" ]] && MAIN_BRANCH="main"

CURRENT_BRANCH=$(git -C "$TOPLEVEL" branch --show-current 2>/dev/null || true)

# Candidates: local branches whose upstream is gone.
mapfile -t CANDIDATES < <(git -C "$TOPLEVEL" branch -vv | grep ': gone]' | awk '{print $1}' | sed 's/^\*//')

# SAFE_ANCESTOR holds branches `git branch -d` will happily delete on its own
# (they pass its own ancestor-of-main check). SAFE_CHERRY holds branches that
# FAIL that same ancestor check (by definition — that's the false-positive
# case this script exists to rescue) but whose every commit's patch-id
# already landed on main per `git cherry`. Because `-d` looks only at
# ancestry, it will always refuse a SAFE_CHERRY branch even though the
# content is safe — so those need `-D` instead of `-d` once cherry-verified.
SAFE_ANCESTOR=()
SAFE_CHERRY=()
NOT_SAFE=()

for branch in "${CANDIDATES[@]}"; do
  [[ -z "$branch" ]] && continue
  if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
    # Never touch the branch currently checked out here.
    continue
  fi

  # First try the plain ancestor check `git branch -d` itself relies on —
  # if the branch is already a direct ancestor of main, it's a normal
  # safe-delete case and needs no further verification.
  if git -C "$TOPLEVEL" merge-base --is-ancestor "$branch" "$MAIN_BRANCH" 2>/dev/null; then
    SAFE_ANCESTOR+=("$branch")
    continue
  fi

  # Not a direct ancestor — check the squash-merge false-positive case.
  # `git cherry main <branch>` diffs each commit's patch-id against main:
  #   - line prefixed with "-": patch-id already exists on main (safe)
  #   - line prefixed with "+": patch-id not found on main (real unmerged content)
  CHERRY_OUTPUT=$(git -C "$TOPLEVEL" cherry "$MAIN_BRANCH" "$branch" 2>/dev/null || true)

  if [[ -z "$CHERRY_OUTPUT" ]]; then
    # No commits unique to the branch at all — safe.
    SAFE_ANCESTOR+=("$branch")
  elif grep -q '^+' <<<"$CHERRY_OUTPUT"; then
    NOT_SAFE+=("$branch")
  else
    SAFE_CHERRY+=("$branch")
  fi
done

for branch in "${NOT_SAFE[@]}"; do
  echo "NOT SAFE (unmerged commits found via git cherry): ${branch}"
done

TOTAL_SAFE=$(( ${#SAFE_ANCESTOR[@]} + ${#SAFE_CHERRY[@]} ))
echo "Safe to delete (${TOTAL_SAFE}):"
for branch in "${SAFE_ANCESTOR[@]}"; do
  echo "  ${branch}"
done
for branch in "${SAFE_CHERRY[@]}"; do
  echo "  ${branch} (squash-merge verified via git cherry)"
done

if [[ "$TOTAL_SAFE" -eq 0 ]]; then
  exit 0
fi

if [[ "$ASSUME_YES" -eq 0 ]]; then
  REPLY=""
  read -r -p "Delete these ${TOTAL_SAFE} branch(es)? [y/N] " REPLY || true
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *)
      echo "Aborted — no branches deleted."
      exit 0
      ;;
  esac
fi

for branch in "${SAFE_ANCESTOR[@]}"; do
  git -C "$TOPLEVEL" branch -d "$branch"
done
for branch in "${SAFE_CHERRY[@]}"; do
  # -d would refuse this branch (that's exactly the false positive being
  # rescued here) even though `git cherry` already proved its content is
  # on main, so -D is the correct, safe choice for this bucket only.
  git -C "$TOPLEVEL" branch -D "$branch"
done
