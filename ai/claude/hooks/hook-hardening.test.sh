#!/usr/bin/env bash
# Regression test for ai-skills#686: two hardening bugs shared across the
# reminder/track hook families in this directory.
#
#   (a) non-dict tool_input guard — a string tool_input (seen from some
#       clients/replay tooling) crashed several hooks with an uncaught
#       AttributeError instead of exiting 0 silently.
#   (b) CLI flag-order regex tolerance — issue-update-reminder.py and
#       git-ops-reminder.py's BASH_COMMAND_RE/COMMAND_RE required the CLI
#       binary immediately adjacent to the subcommand, so
#       `gh --repo owner/repo issue comment 123` and
#       `glab -R group/repo issue close 5` didn't fire the nudge even
#       though the same commands with flags after the subcommand did.
#
# Usage: hook-hardening.test.sh
# Exits 0 on pass, 1 on failure (prints a diagnostic per failure).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

# --- (a) non-dict tool_input must not crash any of these files ---
NONDICT_FILES=(
  git-ops-reminder.py
  git-ops-track.py
  issue-create-reminder.py
  issue-create-track.py
  issue-update-reminder.py
  issue-update-track.py
  ticket-write-verify-reminder.py
  ticket-write-verify-track.py
  branch-guard-track.py
)
for f in "${NONDICT_FILES[@]}"; do
  out=$(echo '{"tool_input": "not-a-dict", "session_id":"hook-hardening-test"}' | python3 "$SCRIPT_DIR/$f" 2>&1)
  code=$?
  if [[ "$code" -ne 0 ]] || grep -qi "traceback" <<<"$out"; then
    echo "FAIL: $f crashed on non-dict tool_input (exit $code): $out" >&2
    fail=1
  fi
done

# --- (b) CLI flag-order tolerance, positive cases ---
assert_fires() {
  local file="$1" payload="$2" label="$3"
  local out
  out=$(echo "$payload" | python3 "$SCRIPT_DIR/$file" 2>&1)
  if [[ -z "$out" ]]; then
    echo "FAIL: $label did not fire the nudge (expected output, got none)" >&2
    fail=1
  fi
}

assert_silent() {
  local file="$1" payload="$2" label="$3"
  local out
  out=$(echo "$payload" | python3 "$SCRIPT_DIR/$file" 2>&1)
  if [[ -n "$out" ]]; then
    echo "FAIL: $label fired the nudge but should have stayed silent, got: $out" >&2
    fail=1
  fi
}

assert_fires issue-update-reminder.py \
  '{"tool_name":"Bash","tool_input":{"command":"gh --repo x/y issue comment 1 --body z"},"session_id":"hook-hardening-test-a"}' \
  "gh --repo x/y issue comment 1 --body z"

assert_fires issue-update-reminder.py \
  '{"tool_name":"Bash","tool_input":{"command":"glab -R x/y issue close 1"},"session_id":"hook-hardening-test-a"}' \
  "glab -R x/y issue close 1"

assert_fires issue-create-reminder.py \
  '{"tool_name":"Bash","tool_input":{"command":"gh --repo x/y issue create --title t"},"session_id":"hook-hardening-test-b"}' \
  "gh --repo x/y issue create --title t"

assert_fires git-ops-reminder.py \
  '{"tool_input":{"command":"gh --repo x/y pr create --title t"},"session_id":"hook-hardening-test-c"}' \
  "gh --repo x/y pr create --title t"

# --- (b) regression: originally-adjacent forms must still match ---
assert_fires issue-update-reminder.py \
  '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 5 --body hi"},"session_id":"hook-hardening-test-d"}' \
  "gh issue comment 5 --body hi (adjacent, pre-existing form)"

assert_fires git-ops-reminder.py \
  '{"tool_input":{"command":"git commit -m x"},"session_id":"hook-hardening-test-e"}' \
  "git commit -m x (adjacent, pre-existing form)"

# --- (b) negative control: must not fire across a shell separator into an
# unrelated command that merely contains the trigger words ---
assert_silent issue-update-reminder.py \
  '{"tool_name":"Bash","tool_input":{"command":"gh auth status && echo issue comment done"},"session_id":"hook-hardening-test-f"}' \
  "gh auth status && echo issue comment done (unrelated multi-command line)"

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: non-dict tool_input guard holds across 9 hook files; CLI flag-order tolerance fires on flagged/adjacent forms without false-positiving across shell separators"
fi

exit "$fail"
