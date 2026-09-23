#!/usr/bin/env bash
# Identify and delete local branches whose remote tracking ref is gone, without
# the false-negative session-close's inline pipeline has: `git branch -d`'s
# ancestor check fails on a squash-merged branch even though its content
# genuinely landed on main, so those branches pile up across sessions instead
# of getting cleaned up (see git-ops issue #871).
#
# Squash-merge safety is verified via `git merge-tree --write-tree`, not
# per-commit patch-id matching (`git cherry`) — patch-id matching was tried
# first and rejected: it misses multi-commit squash merges entirely (no
# single commit's patch-id survives a squash into one combined commit, so
# every commit reads as "unmerged" even though the branch's full diff against
# main is empty), and a same-patch-id coincidence (e.g. a revert-then-readd of
# identical content) can produce a false "safe" verdict. `merge-tree` instead
# performs a real, working-tree-free 3-way merge of the branch onto main and
# compares the resulting tree to main's current tree: if merging the branch in
# would change nothing, the branch's content is genuinely already on main,
# regardless of how many commits or what shape the merge took. Requires git
# 2.38+ for the `--write-tree` form.
#
# Usage: prune-branches.sh [repo-path] [--yes|-y]
#   repo-path — defaults to the current working directory
#   --yes/-y  — skip the interactive confirmation and delete immediately
#
# Output: a labeled "safe to delete" list (with count), a separate
# "NOT SAFE (merging would still change main): <branch>" line for each
# excluded branch, then either the confirm prompt or (with --yes) the delete
# results.
# Exits 0 on success (including "nothing to do"), 1 on usage error.

set -uo pipefail

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

TOPLEVEL=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$TOPLEVEL" ]]; then
  echo "error: '$REPO' is not a git repository" >&2
  exit 1
fi

# Sync gone-branch state before reading it.
git -C "$TOPLEVEL" fetch --prune origin >/dev/null 2>&1

# Resolve the default branch. `set -e` is deliberately NOT active in this
# script (see above) specifically so a failing `symbolic-ref` in this
# pipeline can't kill the whole run before the "main" fallback ever executes
# — that was a real bug (silent exit 128, no output) in an earlier version of
# this script when `origin/HEAD` wasn't set and the actual default branch
# wasn't literally named "main".
MAIN_BRANCH=$(git -C "$TOPLEVEL" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [[ -z "$MAIN_BRANCH" ]]; then
  # No origin/HEAD — try the two common default names before giving up.
  if git -C "$TOPLEVEL" show-ref --verify --quiet refs/heads/main; then
    MAIN_BRANCH="main"
  elif git -C "$TOPLEVEL" show-ref --verify --quiet refs/heads/master; then
    MAIN_BRANCH="master"
  else
    echo "error: could not determine the default branch (no origin/HEAD, no local main or master) — pass it explicitly by checking out the repo's actual default branch first" >&2
    exit 1
  fi
fi

CURRENT_BRANCH=$(git -C "$TOPLEVEL" branch --show-current 2>/dev/null)

# Candidates: local branches whose upstream is gone.
mapfile -t CANDIDATES < <(git -C "$TOPLEVEL" branch -vv | grep ': gone]' | awk '{print $1}' | sed 's/^\*//')

MAIN_TREE=$(git -C "$TOPLEVEL" rev-parse "${MAIN_BRANCH}^{tree}")

# SAFE_ANCESTOR holds branches `git branch -d` will happily delete on its own
# (they pass its own ancestor-of-main check) — plain fast-forward-merged
# branches, the common case. SAFE_MERGE holds branches that FAIL that same
# ancestor check (by definition — that's the false-positive case this script
# exists to rescue) but whose content, per a real `merge-tree` computation, is
# already fully represented on main regardless of commit shape. Because `-d`
# looks only at ancestry, it will always refuse a SAFE_MERGE branch even
# though the content is safe — so those need `-D` instead of `-d` once
# merge-tree-verified.
SAFE_ANCESTOR=()
SAFE_MERGE=()
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

  # Not a direct ancestor — check whether merging the branch into main would
  # actually change anything. `merge-tree --write-tree` performs a real 3-way
  # merge (using the branch/main merge-base) without touching the working
  # tree or index, and prints the resulting tree's object ID on success. If
  # that resulting tree is identical to main's current tree, merging in this
  # branch would be a no-op — its content, however many commits or whatever
  # squash/rebase shape it took, is already fully present on main.
  RESULT_TREE=$(git -C "$TOPLEVEL" merge-tree --write-tree "$MAIN_BRANCH" "$branch" 2>/dev/null)
  MERGE_STATUS=$?

  if [[ "$MERGE_STATUS" -ne 0 ]]; then
    # A real conflict against main, or the merge itself failed outright —
    # not safe to assume anything here.
    NOT_SAFE+=("$branch")
  elif [[ "$RESULT_TREE" == "$MAIN_TREE" ]]; then
    SAFE_MERGE+=("$branch")
  else
    NOT_SAFE+=("$branch")
  fi
done

for branch in "${NOT_SAFE[@]}"; do
  echo "NOT SAFE (merging would still change main): ${branch}"
done

TOTAL_SAFE=$(( ${#SAFE_ANCESTOR[@]} + ${#SAFE_MERGE[@]} ))
echo "Safe to delete (${TOTAL_SAFE}):"
for branch in "${SAFE_ANCESTOR[@]}"; do
  echo "  ${branch}"
done
for branch in "${SAFE_MERGE[@]}"; do
  echo "  ${branch} (squash/rebase-merge verified via git merge-tree)"
done

if [[ "$TOTAL_SAFE" -eq 0 ]]; then
  exit 0
fi

if [[ "$ASSUME_YES" -eq 0 ]]; then
  REPLY=""
  read -r -p "Delete these ${TOTAL_SAFE} branch(es)? [y/N] " REPLY
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
for branch in "${SAFE_MERGE[@]}"; do
  # -d would refuse this branch (that's exactly the false positive being
  # rescued here) even though merge-tree already proved merging it in would
  # be a no-op against main, so -D is the correct, safe choice for this
  # bucket only.
  git -C "$TOPLEVEL" branch -D "$branch"
done
