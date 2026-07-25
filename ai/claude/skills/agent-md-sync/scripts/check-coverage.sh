#!/usr/bin/env bash
# Cross-checks discover-components.sh's reported components against an
# independent, marker-file-only scan of the same repo(s) — surfaces any
# directory discover-components.sh's per-category rules might be missing.
#
# Run this against a new/unfamiliar repo layout, or after changing
# discover-components.sh's detection rules, instead of re-deriving coverage
# by hand each time. Any MISSED line is evidence a detection rule needs
# widening — not a reason to widen it preemptively.
#
# Usage: check-coverage.sh <repo-path> [repo-path...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
  echo "Usage: check-coverage.sh <repo-path> [repo-path...]" >&2
  exit 1
fi

FIND_EXCLUDES=(-not -path '*/.*/*' -not -path './node_modules/*' -not -path './vendor/*')
GENERIC_SKIP_RE="^(roles|modules|charts|playbooks|node_modules|vendor|\.git|\.github|\.claude|\.cursor)$"

check_repo() {
  local repo="$1"
  (
    cd "$repo" || { echo "ERROR: cannot cd to $repo" >&2; return 1; }

    # discover-components.sh's generic category keeps a leading "./" that the
    # other categories strip — normalize here rather than touch that output.
    mapfile -t reported < <(bash "$SCRIPT_DIR/discover-components.sh" . | cut -d: -f2 | sed 's|^\./||')

    is_reported() {
      local path="$1" r
      for r in "${reported[@]}"; do
        [[ "$r" == "$path" ]] && return 0
      done
      return 1
    }

    local missed=0 dir

    # Ansible roles — tasks/main.yml or tasks/main.yaml, at any depth
    while IFS= read -r -d '' f; do
      dir="${f%/tasks/main.yml}"
      dir="${dir%/tasks/main.yaml}"
      dir="${dir#./}"
      if ! is_reported "$dir"; then
        echo "MISSED:ansible-role:${dir}"
        missed=$((missed + 1))
      fi
    done < <(find . "${FIND_EXCLUDES[@]}" \( -path '*/tasks/main.yml' -o -path '*/tasks/main.yaml' \) -print0 2>/dev/null)

    # Terraform — main.tf, at any depth
    while IFS= read -r -d '' f; do
      dir="${f%/main.tf}"
      dir="${dir#./}"
      if ! is_reported "$dir"; then
        echo "MISSED:terraform:${dir}"
        missed=$((missed + 1))
      fi
    done < <(find . "${FIND_EXCLUDES[@]}" -name main.tf -print0 2>/dev/null)

    # Helm charts — Chart.yaml, at any depth
    while IFS= read -r -d '' f; do
      dir="${f%/Chart.yaml}"
      dir="${dir#./}"
      if ! is_reported "$dir"; then
        echo "MISSED:helm-chart:${dir}"
        missed=$((missed + 1))
      fi
    done < <(find . "${FIND_EXCLUDES[@]}" -name Chart.yaml -print0 2>/dev/null)

    # Generic — README.md, first-level only (discover-components.sh only ever
    # treats depth-1 READMEs as a component; deeper ones aren't its category)
    while IFS= read -r -d '' f; do
      dir="${f%/README.md}"
      dir="${dir#./}"
      echo "$dir" | grep -qE "$GENERIC_SKIP_RE" && continue
      if ! is_reported "$dir"; then
        echo "MISSED:generic:${dir}"
        missed=$((missed + 1))
      fi
    done < <(find . -mindepth 2 -maxdepth 2 "${FIND_EXCLUDES[@]}" -name README.md -print0 2>/dev/null)

    echo "${missed} potential blind spot(s) in ${repo}"
  )
}

for repo in "$@"; do
  echo "=== ${repo} ==="
  check_repo "$repo"
  echo
done
