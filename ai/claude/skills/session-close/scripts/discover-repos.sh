#!/usr/bin/env bash
# Scans git repos for open work before closing a session.
# When a .code-workspace file exists in $PWD, scans those workspace folders explicitly.
# Falls back to ~/Projects/workspace/*.code-workspace, then a depth-3 search under
# ~/Projects/**/*.code-workspace, before giving up on workspace detection entirely.
# Always also scans ~/Projects/ (up to 4 levels deep) to catch repos not listed in the workspace.
# Output: REPO:<path>|BRANCH:<branch>|CHANGES:<n>|WORKTREES:<n>|AHEAD_BRANCHES:<n>|RECENT:<y|n>
#
# RECENT_HOURS: env var controlling the "recently active" threshold in hours (default: 8)
# SHOW_ALL_REPOS=1: disable the single-repo-session RECENT:n exclusion below
# SESSION_SINGLE_REPO=1: force single-repo-session filtering even without a one-folder workspace

RECENT_HOURS="${RECENT_HOURS:-8}"
SHOW_ALL_REPOS="${SHOW_ALL_REPOS:-0}"
SESSION_SINGLE_REPO="${SESSION_SINGLE_REPO:-0}"

check_repo() {
  local repo="$1"

  local branch
  branch=$(git -C "$repo" branch --show-current 2>/dev/null)
  [[ -z "$branch" ]] && return  # not a git repo, detached HEAD, or worktree subdir

  local changes
  changes=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  local worktree_count extra_worktrees
  worktree_count=$(git -C "$repo" worktree list 2>/dev/null | wc -l | tr -d ' ')
  extra_worktrees=$(( worktree_count - 1 ))
  [[ $extra_worktrees -lt 0 ]] && extra_worktrees=0

  local base_ref ahead_branches user_email
  base_ref=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  [[ -z "$base_ref" ]] && base_ref="origin/main"
  user_email=$(git -C "$repo" config user.email 2>/dev/null)
  ahead_branches=$(git -C "$repo" branch -r 2>/dev/null \
    | grep -v "HEAD" \
    | grep -v -E "origin/(main|master)$" \
    | tr -d ' ' \
    | while read -r rb; do
        count=$(git -C "$repo" rev-list --count "${base_ref}..${rb}" 2>/dev/null) || count=0
        if [[ "${count:-0}" -gt 0 ]]; then
          # Only count branches where the tip commit was authored by this user
          tip_author=$(git -C "$repo" log -1 --format="%ae" "${rb}" 2>/dev/null)
          [[ "$tip_author" == "$user_email" ]] && echo "$rb"
        fi
      done \
    | wc -l | tr -d ' ')

  local not_main=0
  [[ ! "${branch,,}" =~ ^(main|master)$ ]] && not_main=1

  # RECENT: did this repo have a commit within the last RECENT_HOURS hours?
  local recent="n"
  local cutoff_ts recent_commit_ts
  cutoff_ts=$(date -d "-${RECENT_HOURS} hours" +%s 2>/dev/null \
    || date -v "-${RECENT_HOURS}H" +%s 2>/dev/null)  # GNU vs BSD date
  if [[ -n "$cutoff_ts" ]]; then
    recent_commit_ts=$(git -C "$repo" log -1 --format="%ct" 2>/dev/null)
    if [[ -n "$recent_commit_ts" && "$recent_commit_ts" -ge "$cutoff_ts" ]]; then
      recent="y"
    fi
  fi

  if [[ "$not_main" -eq 1 || "$changes" -gt 0 || "$extra_worktrees" -gt 0 || "$ahead_branches" -gt 0 ]]; then
    echo "REPO:${repo}|BRANCH:${branch}|CHANGES:${changes}|WORKTREES:${extra_worktrees}|AHEAD_BRANCHES:${ahead_branches}|RECENT:${recent}"
  fi
}

# Collect candidate repo paths into a temp file for deduplication.
# PRIMARY_PATHS tracks repos explicitly in-scope for this session (workspace-listed
# folders, the CWD repo) as opposed to repos only found by the broad ~/Projects sweep —
# used below to decide which RECENT:n repos are noise vs. the session's own work.
REPO_PATHS=$(mktemp)
PRIMARY_PATHS=$(mktemp)
trap 'rm -f "$REPO_PATHS" "$PRIMARY_PATHS"' EXIT

# Pick the workspace file rooted at $PWD (has "path": "." in folders).
# Avoids grabbing project-specific workspace files that share the same directory.
WORKSPACE_FILE=""
while IFS= read -r candidate; do
  is_root=$(python3 - "$candidate" <<'PYEOF' 2>/dev/null
import json, sys
data = json.load(open(sys.argv[1]))
print("yes" if any(f.get("path","") == "." for f in data.get("folders",[])) else "")
PYEOF
)
  if [[ "$is_root" == "yes" ]]; then
    WORKSPACE_FILE="$candidate"
    break
  fi
done < <(find "$PWD" -maxdepth 1 -name "*.code-workspace" 2>/dev/null)

# Not every multi-root workspace is rooted at $PWD (e.g. a homelab workspace that
# lives under ~/Projects/workspace/ while $PWD is one of its member repos). Before
# falling back to the full ~/Projects tree sweep, probe known workspace locations.
if [[ -z "$WORKSPACE_FILE" ]]; then
  WORKSPACE_FILE=$(find "${PROJECTS_BASE:-$HOME/Projects}/workspace" -maxdepth 1 -name "*.code-workspace" 2>/dev/null | head -1)
fi
if [[ -z "$WORKSPACE_FILE" ]]; then
  WORKSPACE_FILE=$(find "${PROJECTS_BASE:-$HOME/Projects}" -maxdepth 3 -name "*.code-workspace" 2>/dev/null | head -1)
fi

# If a workspace file is found, scan its listed folders explicitly.
# This catches repos outside ~/Projects/ that are pinned in the workspace.
WORKSPACE_FOLDER_COUNT=0
if [[ -n "$WORKSPACE_FILE" ]]; then
  WORKSPACE_DIR=$(dirname "$WORKSPACE_FILE")
  while IFS= read -r folder_path; do
    if [[ "$folder_path" = /* ]]; then
      abs_path="$folder_path"
    else
      abs_path=$(cd "$WORKSPACE_DIR" && cd "$folder_path" 2>/dev/null && pwd)
    fi
    if [[ -n "$abs_path" ]]; then
      echo "$abs_path" >> "$REPO_PATHS"
      echo "$abs_path" >> "$PRIMARY_PATHS"
    fi
  done < <(python3 -c "
import json
data = json.load(open('$WORKSPACE_FILE'))
for f in data.get('folders', []):
    p = f.get('path', '')
    if p:
        print(p)
" 2>/dev/null)
  WORKSPACE_FOLDER_COUNT=$(python3 -c "import json; print(len(json.load(open('$WORKSPACE_FILE')).get('folders', [])))" 2>/dev/null || echo 0)
fi

# Always scan ~/Projects/ at depth 4 to catch repos not listed in the workspace,
# including those nested three levels deep (e.g. ~/Projects/org/subgroup/repo).
find "${PROJECTS_BASE:-$HOME/Projects}" -maxdepth 4 -name ".git" -type d 2>/dev/null \
  | sed 's|/.git||' \
  | grep -v "/.claude/worktrees/" \
  >> "$REPO_PATHS"

# Always include the current working repo, even if it's outside ~/Projects/ and
# not listed in the workspace file (e.g. a repo cloned to a custom path).
CWD_GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$CWD_GIT_ROOT" ]]; then
  echo "$CWD_GIT_ROOT" >> "$REPO_PATHS"
  echo "$CWD_GIT_ROOT" >> "$PRIMARY_PATHS"
fi

# A single-folder workspace (or an explicit SESSION_SINGLE_REPO override, set by the
# caller when conversation context unambiguously points to one repo) means this
# session is scoped to one repo. In that case, exclude RECENT:n repos found only by
# the broad ~/Projects sweep from the default output — they're leftover/archive
# noise, not part of this session — unless SHOW_ALL_REPOS=1 is set.
FILTER_RECENT_N=0
if [[ "$SHOW_ALL_REPOS" != "1" ]] && { [[ "$WORKSPACE_FOLDER_COUNT" -eq 1 ]] || [[ "$SESSION_SINGLE_REPO" == "1" ]]; }; then
  FILTER_RECENT_N=1
fi

# Sort, deduplicate, and check each repo
sort -u "$REPO_PATHS" | while read -r repo; do
  check_repo "$repo"
done | while IFS= read -r line; do
  if [[ "$FILTER_RECENT_N" == "1" ]] && [[ "$line" == *"RECENT:n"* ]]; then
    repo_path="${line#REPO:}"
    repo_path="${repo_path%%|*}"
    grep -Fxq "$repo_path" "$PRIMARY_PATHS" 2>/dev/null || continue
  fi
  echo "$line"
done
