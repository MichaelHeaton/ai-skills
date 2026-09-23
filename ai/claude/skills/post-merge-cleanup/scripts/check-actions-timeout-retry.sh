#!/usr/bin/env bash
# Regression check for issue #863: post-merge-cleanup Step 5 must document a
# retry path when `gh run list` fails with a network/timeout error, rather
# than treating that failure as a red Actions run.
#
# Reproduces the real-world failure mode: `gh run watch` / `gh run list` can
# exit non-zero on API i/o timeout even though the workflow it was checking
# already succeeded. Before #863, SKILL.md's Step 5 had no instruction to
# re-check via `gh run view`/`gh run list --commit`, so an agent following it
# literally would report "✗ FAILED" on a bare timeout.
#
# This script does two things:
#   1. Simulates the exact failure via a stub `gh` binary that emits a
#      `dial tcp ... i/o timeout` error and a non-zero exit — the same shape
#      of error the ticket describes.
#   2. Asserts SKILL.md's Step 5 section actually documents the retry-before-
#      reporting-failure behavior (re-fetch via `gh run view`, treat timeout
#      as inconclusive, don't print "FAILED" on a bare timeout).
#
# Usage: ai/claude/skills/post-merge-cleanup/scripts/check-actions-timeout-retry.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$SCRIPT_DIR/../SKILL.md"

if [[ ! -f "$SKILL_MD" ]]; then
  echo "✗ cannot find SKILL.md at $SKILL_MD"
  exit 1
fi

# --- Step 1: reproduce the actual gh failure mode -------------------------
tmp_gh_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_gh_dir"' EXIT

cat > "$tmp_gh_dir/gh" <<'STUB'
#!/usr/bin/env bash
# Stub `gh` that simulates an API i/o timeout on `run list`, and a
# successful conclusion on the retry `run view` call — mirrors a workflow
# that actually succeeded despite the first call timing out.
if [[ "$1" == "run" && "$2" == "list" ]]; then
  echo "error connecting to api.github.com" >&2
  echo "dial tcp 140.82.112.6:443: i/o timeout" >&2
  exit 1
elif [[ "$1" == "run" && "$2" == "view" ]]; then
  echo '{"conclusion":"success","status":"completed","url":"https://github.com/example/repo/actions/runs/123"}'
  exit 0
fi
STUB
chmod +x "$tmp_gh_dir/gh"

set +e
PATH="$tmp_gh_dir:$PATH" gh run list --branch main --limit 1 --json status,conclusion,name,url >/tmp/gh_timeout_stdout.$$ 2>/tmp/gh_timeout_stderr.$$
first_call_exit=$?
set -e

if [[ $first_call_exit -eq 0 ]]; then
  echo "✗ stub setup broken: expected the first gh call to fail with a timeout"
  exit 1
fi

if ! grep -q "i/o timeout" "/tmp/gh_timeout_stderr.$$"; then
  echo "✗ stub setup broken: expected a dial tcp / i/o timeout error"
  rm -f "/tmp/gh_timeout_stdout.$$" "/tmp/gh_timeout_stderr.$$"
  exit 1
fi
rm -f "/tmp/gh_timeout_stdout.$$" "/tmp/gh_timeout_stderr.$$"

echo "reproduced: gh run list fails with a network/timeout error (exit $first_call_exit) while the underlying workflow succeeded"

# --- Step 2: assert SKILL.md documents the retry-before-failure behavior --
missing=()

grep -qi "dial tcp\|network/timeout\|timeout" "$SKILL_MD" || missing+=("mentions network/timeout error as a distinct case from a real failed run")
grep -q "gh run view" "$SKILL_MD" || missing+=("documents retrying via \`gh run view\`")
grep -qi "inconclusive" "$SKILL_MD" || missing+=("documents treating a re-verified timeout as inconclusive, not FAILED")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "✗ SKILL.md Step 5 does not document the timeout re-check behavior from issue #863:"
  for item in "${missing[@]}"; do
    echo "  - $item"
  done
  exit 1
fi

echo "✓ SKILL.md documents the timeout re-check behavior (retry via gh run view, inconclusive framing)"
