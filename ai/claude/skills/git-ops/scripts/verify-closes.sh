#!/usr/bin/env bash
# Verify that every issue a merged PR's body claims to close (via a Closes/Fixes/Resolves
# keyword) actually closed. GitHub's auto-close is silent on failure — a malformed keyword,
# a number that never matched an issue, or a wrong-repo reference leaves an issue open with
# no error anywhere. Automates git-ops's "Post-merge issue verification" step instead of
# hand-writing a `for n in ...` loop after every merge.
#
# Usage: verify-closes.sh <pr-number> [owner/repo]
#   owner/repo — optional; defaults to gh's own remote resolution for the current repo
# Output: one line per referenced issue:
#   CLOSED:<N>  — matches the PR's claim, no action needed
#   OPEN:<N>    — auto-close didn't fire; close it manually
#   ERROR:<N>   — could not fetch the issue's state
# Exits 1 if any referenced issue is OPEN or errored, 0 otherwise (including when no
# Closes/Fixes/Resolves references are found — that's not a failure, just nothing to check).

set -euo pipefail

PR="${1:-}"
REPO="${2:-}"
[[ -z "$PR" ]] && { echo "usage: verify-closes.sh <pr-number> [owner/repo]" >&2; exit 1; }

REPO_FLAG=()
[[ -n "$REPO" ]] && REPO_FLAG=(--repo "$REPO")

BODY=$(gh pr view "$PR" "${REPO_FLAG[@]}" --json body --jq .body)

ISSUES=$(grep -oiE '(close[sd]?|fixe?[sd]?|resolve[sd]?):?[[:space:]]+#[0-9]+' <<<"$BODY" \
  | grep -oE '#[0-9]+' | tr -d '#' | sort -un)

if [[ -z "$ISSUES" ]]; then
  echo "No Closes/Fixes/Resolves references found in PR #${PR} body."
  exit 0
fi

EXIT_CODE=0
while read -r n; do
  [[ -z "$n" ]] && continue
  state=$(gh issue view "$n" "${REPO_FLAG[@]}" --json state --jq .state 2>/dev/null) || {
    echo "ERROR:${n} — could not fetch issue state"
    EXIT_CODE=1
    continue
  }
  if [[ "$state" == "CLOSED" ]]; then
    echo "CLOSED:${n}"
  else
    echo "OPEN:${n}"
    EXIT_CODE=1
  fi
done <<<"$ISSUES"

exit $EXIT_CODE
