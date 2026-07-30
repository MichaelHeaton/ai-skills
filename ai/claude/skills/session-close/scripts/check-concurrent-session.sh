#!/usr/bin/env bash
# Best-effort check for another Claude Code session already operating on a repo.
# Excludes the current session's own claude process (walked up from $PPID) so the
# check doesn't self-match on every run, and filters out stale/orphaned processes
# whose reported cwd no longer exists on disk (e.g. a worktree deleted mid-session).
#
# Usage: check-concurrent-session.sh <repo-path>
# Output: LIVE:<pid>:<cwd>   — another session appears to be actively working here
#         STALE:<pid>:<cwd>  — a claude process matched, but its cwd is gone; not a live collision
# Exits 0 always — this is advisory, never a hard gate.

REPO="$1"
[[ -z "$REPO" ]] && { echo "usage: check-concurrent-session.sh <repo-path>" >&2; exit 0; }

REPO_REAL=$(realpath "$REPO" 2>/dev/null)
[[ -z "$REPO_REAL" ]] && exit 0

# Walk up the process tree from this script's own shell to find every ancestor
# claude PID — these are "this session," not a concurrent one.
declare -A OWN_PIDS
pid=$$
while [[ -n "$pid" && "$pid" != "1" ]]; do
  ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  [[ -z "$ppid" || "$ppid" == "0" ]] && break
  comm=$(ps -o command= -p "$ppid" 2>/dev/null)
  if [[ "$comm" == *"/claude"* || "$comm" == "claude"* ]]; then
    OWN_PIDS["$ppid"]=1
  fi
  pid="$ppid"
done

# -a ANDs the selectors: only the cwd file descriptor of processes named claude.
# Plain `lsof -c claude | grep <repo>` (the old form) also matched any open file
# under the repo, not just cwd — a much noisier signal.
while read -r cpid cwd; do
  [[ -z "$cpid" ]] && continue
  [[ -n "${OWN_PIDS[$cpid]:-}" ]] && continue
  if [[ -d "$cwd" ]]; then
    echo "LIVE:${cpid}:${cwd}"
  else
    echo "STALE:${cpid}:${cwd}"
  fi
done < <(lsof -a -d cwd -c claude 2>/dev/null | awk -v repo="$REPO_REAL" 'NR>1 && index($NF, repo)==1 {print $2, $NF}')
