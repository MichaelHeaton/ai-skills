#!/usr/bin/env bash
# Check which component AGENT.md files are stale or missing for a PR branch.
# Usage: check-pr-diff.sh [base-branch]
# Output: one line per affected component — STATUS:PATH
#   STALE:<path>   — has AGENT.md, code changed, AGENT.md not updated in this branch
#   MISSING:<path> — recognized as a component, no AGENT.md exists
#   OK:<path>      — AGENT.md was updated alongside its code

set -euo pipefail

# Determine base branch
BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  if git rev-parse --verify main &>/dev/null 2>&1; then
    BASE="main"
  elif git rev-parse --verify master &>/dev/null 2>&1; then
    BASE="master"
  else
    echo "ERROR: cannot determine base branch (tried main, master)" >&2
    exit 1
  fi
fi

# Load ignore list
declare -A IGNORED
if [[ -f ".agent-md-ignore" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"  # strip inline comments
    line="${line// /}"  # strip spaces
    [[ -z "$line" ]] && continue
    IGNORED["$line"]=1
  done < ".agent-md-ignore"
fi

# This script only reports on existing files — it never writes a new
# AGENT.md/AGENTS.md itself, so there's no need to resolve one preferred
# name. A mixed-migration repo may have some components on AGENTS.md and
# others still on the legacy AGENT.md, so every existence check below
# always falls back to either filename rather than assuming one.
EITHER_AGENT_MD_RE='(^|/)AGENTS?\.md$'

has_either_agent_md() {
  [[ -f "$1/AGENT.md" || -f "$1/AGENTS.md" ]]
}

# Get all files changed in this branch vs base (three-dot diff for branch-only changes)
mapfile -t ALL_CHANGED < <(git diff --name-only "${BASE}...HEAD" 2>/dev/null || git diff --name-only "${BASE}..HEAD" 2>/dev/null || true)

if [[ ${#ALL_CHANGED[@]} -eq 0 ]]; then
  exit 0
fi

# Which component dirs had EITHER convention's file updated in this branch?
declare -A AGENT_UPDATED_DIRS
while IFS= read -r -d '' f; do
  dir=$(dirname "$f")
  AGENT_UPDATED_DIRS["$dir"]=1
done < <(printf '%s\0' "${ALL_CHANGED[@]}" | grep -zE 'AGENTS?\.md$' || true)

# Is a directory a recognized component type?
is_component_dir() {
  local dir="$1"
  # Ansible role
  [[ -f "$dir/tasks/main.yml" || -f "$dir/tasks/main.yaml" ]] && return 0
  # Terraform module
  [[ -f "$dir/main.tf" ]] && return 0
  # Helm chart
  [[ -f "$dir/Chart.yaml" ]] && return 0
  return 1
}

# Find the nearest ancestor component boundary for a given file path.
# Walks up from the file's directory until it hits a dir with AGENT.md
# or a recognized component dir, or runs out of path depth.
# Prints "TYPE:DIR" or nothing if no component boundary found.
find_component_boundary() {
  local file="$1"
  local dir
  dir=$(dirname "$file")

  while [[ "$dir" != "." && "$dir" != "" ]]; do
    # Skip ignored paths
    if [[ -v "IGNORED[$dir]" ]]; then
      return 0
    fi

    if has_either_agent_md "$dir"; then
      echo "has-agent-md:$dir"
      return 0
    fi

    if is_component_dir "$dir"; then
      echo "component:$dir"
      return 0
    fi

    dir=$(dirname "$dir")
  done
}

# Process each changed file
declare -A REPORTED_DIRS

for file in "${ALL_CHANGED[@]}"; do
  # Skip AGENT.md/AGENTS.md files themselves (either convention)
  [[ "$file" =~ $EITHER_AGENT_MD_RE ]] && continue

  boundary=$(find_component_boundary "$file") || continue
  [[ -z "$boundary" ]] && continue

  boundary_type="${boundary%%:*}"
  boundary_dir="${boundary#*:}"

  # Skip if already reported
  [[ -v "REPORTED_DIRS[$boundary_dir]" ]] && continue
  REPORTED_DIRS["$boundary_dir"]=1

  if [[ "$boundary_type" == "has-agent-md" ]]; then
    if [[ -v "AGENT_UPDATED_DIRS[$boundary_dir]" ]]; then
      echo "OK:$boundary_dir"
    else
      echo "STALE:$boundary_dir"
    fi
  elif [[ "$boundary_type" == "component" ]]; then
    echo "MISSING:$boundary_dir"
  fi
done
