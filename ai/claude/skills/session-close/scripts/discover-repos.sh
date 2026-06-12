#!/usr/bin/env bash
# Scans git repos for open work before closing a session.
# When a .code-workspace file exists in $PWD, scans those workspace folders explicitly.
# Always also scans ~/Projects/ (up to 4 levels deep) to catch repos not listed in the workspace.
# Output: REPO:<path>|BRANCH:<branch>|CHANGES:<n>|WORKTREES:<n>|AHEAD_BRANCHES:<n>

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

  if [[ "$not_main" -eq 1 || "$changes" -gt 0 || "$extra_worktrees" -gt 0 || "$ahead_branches" -gt 0 ]]; then
    echo "REPO:${repo}|BRANCH:${branch}|CHANGES:${changes}|WORKTREES:${extra_worktrees}|AHEAD_BRANCHES:${ahead_branches}"
  fi
}

# Collect candidate repo paths into a temp file for deduplication
REPO_PATHS=$(mktemp)
trap 'rm -f "$REPO_PATHS"' EXIT

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

# If a workspace file is found, scan its listed folders explicitly.
# This catches repos outside ~/Projects/ that are pinned in the workspace.
if [[ -n "$WORKSPACE_FILE" ]]; then
  WORKSPACE_DIR=$(dirname "$WORKSPACE_FILE")
  while IFS= read -r folder_path; do
    if [[ "$folder_path" = /* ]]; then
      abs_path="$folder_path"
    else
      abs_path=$(cd "$WORKSPACE_DIR" && cd "$folder_path" 2>/dev/null && pwd)
    fi
    [[ -n "$abs_path" ]] && echo "$abs_path" >> "$REPO_PATHS"
  done < <(python3 -c "
import json
data = json.load(open('$WORKSPACE_FILE'))
for f in data.get('folders', []):
    p = f.get('path', '')
    if p:
        print(p)
" 2>/dev/null)
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
[[ -n "$CWD_GIT_ROOT" ]] && echo "$CWD_GIT_ROOT" >> "$REPO_PATHS"

# Sort, deduplicate, and check each repo
sort -u "$REPO_PATHS" | while read -r repo; do
  check_repo "$repo"
done
