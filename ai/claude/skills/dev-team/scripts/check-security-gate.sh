#!/usr/bin/env bash
# Verifies Manager's third job — the security-control regression gate — is
# actually present in both places it's documented: the dev-team-manager
# agent file (detailed instructions) and the dev-team SKILL.md (orchestration
# summary). Added alongside that gate so a future edit that accidentally
# drops the job (e.g. a careless rewrite of the "N jobs" list) fails loudly
# instead of silently reverting Manager to two jobs.
#
# Also checks the principles/engineering-practices.md cross-reference from
# each file resolves to a real path with the "DevSecOps" line it cites —
# a relative-path typo here would silently break the cited rationale link.
#
# Usage: check-security-gate.sh (no args; run from anywhere in the repo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

MANAGER_FILE="$REPO_ROOT/ai/claude/agents/dev-team-manager.md"
SKILL_FILE="$REPO_ROOT/ai/claude/skills/dev-team/SKILL.md"
PRINCIPLES_FILE="$REPO_ROOT/principles/engineering-practices.md"

fail=0

check() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (missing '$pattern' in $file)"
    fail=1
  fi
}

check "Manager agent file names three jobs" \
  "$MANAGER_FILE" "You have three jobs"

check "Manager agent file has the security-control regression gate job" \
  "$MANAGER_FILE" "Security-control regression gate"

check "Manager agent file requires an owner + revert-by date on the linked ticket" \
  "$MANAGER_FILE" "revert-by date"

check "SKILL.md Step 5 says Manager does three things" \
  "$SKILL_FILE" "Manager does three things, not two"

check "SKILL.md Step 5 lists the security-control regression gate" \
  "$SKILL_FILE" "Security-control regression gate"

check "SKILL.md states this is not a new spawn trigger" \
  "$SKILL_FILE" "not a new spawn trigger"

if [[ ! -f "$PRINCIPLES_FILE" ]]; then
  echo "FAIL: principles/engineering-practices.md not found at $PRINCIPLES_FILE"
  fail=1
else
  check "principles/engineering-practices.md still has the DevSecOps line" \
    "$PRINCIPLES_FILE" "DevSecOps — shift security left"
fi

if [[ $fail -eq 0 ]]; then
  echo "OK: security-control regression gate is documented in both files."
else
  echo "FAILED: one or more checks above did not pass."
fi

exit $fail
