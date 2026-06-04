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

  # Fetch all open issues in one call — no pagination loop needed
  mapfile -t issue_numbers < <(
    gh issue list \
      --repo "${repo}" \
      --state open \
      --json number \
      --limit 1000 \
      --jq '.[].number'
  )

  total=${#issue_numbers[@]}
  echo "  Found ${total} open issues"

  if [[ "${DRY_RUN}" == "1" ]]; then
    for num in "${issue_numbers[@]}"; do
      echo "  [dry-run] would close #${num}"
    done
    echo "  [dry-run] would close ${total} issues in ${repo}"
  else
    closed=0
    for num in "${issue_numbers[@]}"; do
      gh issue close "${num}" \
        --repo "${repo}" \
        --comment "${CLOSE_COMMENT}" \
        --reason "not planned" 2>/dev/null \
        && echo "  ✓ closed #${num}" \
        || echo "  ✗ failed #${num}"
      closed=$((closed + 1))
      sleep 0.3  # stay under secondary rate limit
    done
    echo "  Closed ${closed}/${total} in ${repo}"
  fi
done

echo ""
echo "Done. Open Linear and verify issues are present before deleting the GitHub repos."
