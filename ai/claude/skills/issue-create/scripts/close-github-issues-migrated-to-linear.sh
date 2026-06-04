#!/usr/bin/env bash
# Close open GitHub Issues in repos that have migrated to Linear.
#
# These issues are already tracked in Linear (via the prior bidirectional
# sync). Closing them on GitHub is safe — nothing is lost.
#
# Usage:
#   DRY_RUN=1 bash close-github-issues-migrated-to-linear.sh   # preview only
#   bash close-github-issues-migrated-to-linear.sh              # close all
#
# Requires: gh CLI authenticated with GITHUB_PERSONAL_USER token.

set -euo pipefail

GITHUB_PERSONAL_USER="${GITHUB_PERSONAL_USER:-MichaelHeaton}"
DRY_RUN="${DRY_RUN:-0}"
CLOSE_COMMENT="Closing on GitHub — this issue is tracked in Linear going forward. No work is lost."

REPOS=(
  "MichaelHeaton/memex"
  "MichaelHeaton/claude-skills"
)

export GH_TOKEN
GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")

for repo in "${REPOS[@]}"; do
  echo ""
  echo "==> ${repo}"

  page=1
  total_closed=0

  while true; do
    mapfile -t issue_numbers < <(
      gh issue list \
        --repo "${repo}" \
        --state open \
        --json number \
        --limit 100 \
        --jq '.[].number'
    )

    if [[ ${#issue_numbers[@]} -eq 0 ]]; then
      break
    fi

    for num in "${issue_numbers[@]}"; do
      if [[ "${DRY_RUN}" == "1" ]]; then
        echo "  [dry-run] would close #${num}"
      else
        gh issue close "${num}" \
          --repo "${repo}" \
          --comment "${CLOSE_COMMENT}" \
          --reason "not planned" 2>/dev/null \
          && echo "  ✓ closed #${num}" \
          || echo "  ✗ failed #${num}"
        total_closed=$((total_closed + 1))
        sleep 0.3  # stay under secondary rate limit
      fi
    done
  done

  echo "  Total closed in ${repo}: ${total_closed}"
done

echo ""
echo "Done. Open Linear and verify issues are present before deleting the GitHub repos."
