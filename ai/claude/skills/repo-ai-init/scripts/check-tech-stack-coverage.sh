#!/usr/bin/env bash
# Cross-checks discover.sh's fixed tech-stack manifest list against an
# independent, broader scan for other common build-manifest filenames —
# applies the same coverage-audit pattern as agent-md-sync's
# check-coverage.sh (see its references/coverage-audit-pattern.md) to
# discover.sh's own fixed-list blind spot.
#
# Usage: check-tech-stack-coverage.sh <repo-path> [repo-path...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: check-tech-stack-coverage.sh <repo-path> [repo-path...]" >&2
  exit 1
fi

# Mirrors discover.sh's TECH STACK list exactly — keep these two in sync.
KNOWN=(package.json go.mod Cargo.toml requirements.txt Pipfile pyproject.toml pom.xml build.gradle Gemfile)

# Other common root-level build-manifest filenames discover.sh doesn't check.
CANDIDATES=(deno.json composer.json mix.exs Rakefile build.sbt CMakeLists.txt stack.yaml *.csproj *.sln setup.py)

is_known() {
  local f="$1" k
  for k in "${KNOWN[@]}"; do
    [[ "$k" == "$f" ]] && return 0
  done
  return 1
}

check_repo() {
  local repo="$1"
  (
    cd "$repo" || { echo "ERROR: cannot cd to $repo" >&2; return 1; }
    local missed=0 pattern
    for pattern in "${CANDIDATES[@]}"; do
      for f in $pattern; do
        [[ -e "$f" ]] || continue
        if ! is_known "$f"; then
          echo "MISSED:tech-stack:${f}"
          missed=$((missed + 1))
        fi
      done
    done
    echo "${missed} potential blind spot(s) in ${repo}"
  )
}

for repo in "$@"; do
  echo "=== ${repo} ==="
  check_repo "$repo"
  echo
done
