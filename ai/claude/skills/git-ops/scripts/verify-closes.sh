#!/usr/bin/env bash
# Verify that every issue a PR's body claims to close (via a Closes/Fixes/Resolves keyword)
# actually got recognized by GitHub. Two modes:
#
#   (default, post-merge) — checks each referenced issue's real state via `gh issue view`.
#   GitHub's auto-close is silent on failure — a malformed keyword, a number that never
#   matched an issue, or a wrong-repo reference leaves an issue open with no error anywhere.
#   Automates git-ops's "Post-merge issue verification" step instead of hand-writing a
#   `for n in ...` loop after every merge.
#
#   --pre-merge — checks each referenced issue against the PR's own `closingIssuesReferences`
#   (GitHub's live, pre-merge parse of the body's closing keywords) instead of issue state,
#   since a referenced issue won't actually be CLOSED until the PR merges. Run this right
#   after `gh pr create`/`create_pull_request` when the body's closing clause references more
#   than one issue — it catches a malformed multi-issue clause (e.g. `Closes #141, #134` only
#   links #141) before the PR is treated as ready, instead of discovering it after merge.
#
# Usage: verify-closes.sh [--pre-merge] <pr-number> [owner/repo]
#   owner/repo — optional; defaults to gh's own remote resolution for the current repo
# Output (default, post-merge mode): one line per referenced issue:
#   CLOSED:<N>  — matches the PR's claim, no action needed
#   OPEN:<N>    — auto-close didn't fire; close it manually
#   ERROR:<N>   — could not fetch the issue's state
# Output (--pre-merge mode): one line per referenced issue:
#   LINKED:<N>     — GitHub recognizes #N as a closing reference for this PR
#   NOT-LINKED:<N> — #N follows a closing keyword in the body but GitHub didn't link it;
#                    rewrite it as its own `closes #N` (repeat the keyword per issue)
# Exits 1 if any referenced issue is OPEN/ERROR (post-merge) or NOT-LINKED (--pre-merge), 0
# otherwise (including when no Closes/Fixes/Resolves references are found — that's not a
# failure, just nothing to check).

set -euo pipefail

PRE_MERGE=0
if [[ "${1:-}" == "--pre-merge" ]]; then
  PRE_MERGE=1
  shift
fi

PR="${1:-}"
REPO="${2:-}"
[[ -z "$PR" ]] && { echo "usage: verify-closes.sh [--pre-merge] <pr-number> [owner/repo]" >&2; exit 1; }

REPO_FLAG=()
[[ -n "$REPO" ]] && REPO_FLAG=(--repo "$REPO")

BODY=$(gh pr view "$PR" "${REPO_FLAG[@]}" --json body --jq .body)

# Matches a keyword's full clause, not just the first number after it — a bare
# `(keyword)(space)#N` pattern would only ever catch the first number in
# `Closes #141, #134, #157` and silently miss #134/#157, which is exactly the
# malformed shape this script exists to catch (see git-ops SKILL.md's multi-issue rule).
ISSUES=$(grep -oiE '(close[sd]?|fixe?[sd]?|resolve[sd]?):?[[:space:]]+#[0-9]+([,;/[:space:]]+(close[sd]?|and)?[[:space:]]*#[0-9]+)*' <<<"$BODY" \
  | grep -oE '#[0-9]+' | tr -d '#' | sort -un)

if [[ -z "$ISSUES" ]]; then
  echo "No Closes/Fixes/Resolves references found in PR #${PR} body."
  exit 0
fi

EXIT_CODE=0

if [[ "$PRE_MERGE" -eq 1 ]]; then
  LINKED=$(gh pr view "$PR" "${REPO_FLAG[@]}" --json closingIssuesReferences \
    --jq '.closingIssuesReferences[].number' 2>/dev/null || true)
  while read -r n; do
    [[ -z "$n" ]] && continue
    if grep -qx "$n" <<<"$LINKED"; then
      echo "LINKED:${n}"
    else
      echo "NOT-LINKED:${n} — not recognized as a closing reference; rewrite as its own \`closes #${n}\`"
      EXIT_CODE=1
    fi
  done <<<"$ISSUES"
  exit $EXIT_CODE
fi

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
