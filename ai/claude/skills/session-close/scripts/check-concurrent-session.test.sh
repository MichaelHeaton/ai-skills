#!/usr/bin/env bash
# Regression test for check-concurrent-session.sh's self-exclusion logic.
#
# Covers the false-positive scenario from ai-skills#314: a process shows up in
# lsof with the current session's repo as its cwd, and its --add-dir list is
# identical to the invoking session's own — but it is not a direct ancestor of
# $$, so the PPID-ancestor walk alone can't recognize it as "self". Stubs `ps`
# and `lsof` on PATH so the test runs without a real second Claude process.
#
# Usage: check-concurrent-session.test.sh
# Exits 0 on pass, 1 on failure (prints a diagnostic on failure).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/check-concurrent-session.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

REPO_DIR="$WORK/repo"
mkdir -p "$REPO_DIR"
REPO_REAL=$(cd "$REPO_DIR" && pwd -P)

FAKE_BIN="$WORK/bin"
mkdir -p "$FAKE_BIN"

# Fake `ps`: redirects the real (unknown-ahead-of-time) $$ into a small fixed
# ancestor chain — pid 2001 ("-bash", not claude) -> pid 2002 (this session's
# own claude process) -> pid 1. Any pid not otherwise listed falls through to
# 2001, so the walk always lands on the same fixed chain regardless of the
# real pid of the test's own shell.
cat > "$FAKE_BIN/ps" <<EOF
#!/usr/bin/env bash
mode=""
pid=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) mode="\$2"; shift 2 ;;
    -p) pid="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "\$mode" == "ppid=" ]]; then
  case "\$pid" in
    2001) echo 2002 ;;
    2002) echo 1 ;;
    *) echo 2001 ;;
  esac
elif [[ "\$mode" == "command=" ]]; then
  case "\$pid" in
    2001) echo "-bash" ;;
    2002) echo "/usr/bin/claude --add-dir $REPO_REAL" ;;
    3003) echo "/usr/bin/claude --add-dir $REPO_REAL" ;;
    4004) echo "/usr/bin/claude --add-dir /somewhere/else" ;;
    *) ;;
  esac
fi
EOF
chmod +x "$FAKE_BIN/ps"

# Fake `lsof`: three claude-named processes with cwd == the repo.
# - 2002 is the session's own ancestor (caught by the existing PPID walk).
# - 3003 is NOT an ancestor, but its --add-dir list matches 2002's exactly —
#   the false-positive case from #314. Must be excluded by the new check.
# - 4004 has a different --add-dir list — a genuine other session. Must
#   still be reported as LIVE.
cat > "$FAKE_BIN/lsof" <<EOF
#!/usr/bin/env bash
cat <<LSOF
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
claude 2002 user cwd DIR 1,1 0 1 $REPO_REAL
claude 3003 user cwd DIR 1,1 0 1 $REPO_REAL
claude 4004 user cwd DIR 1,1 0 1 $REPO_REAL
LSOF
EOF
chmod +x "$FAKE_BIN/lsof"

OUTPUT=$(PATH="$FAKE_BIN:$PATH" bash "$TARGET" "$REPO_DIR")

fail=0

if grep -q ":2002:" <<<"$OUTPUT"; then
  echo "FAIL: pid 2002 (direct ancestor) should be excluded, was reported: $OUTPUT" >&2
  fail=1
fi

if grep -q ":3003:" <<<"$OUTPUT"; then
  echo "FAIL: pid 3003 (matching --add-dir, not an ancestor) should be excluded as self, was reported: $OUTPUT" >&2
  fail=1
fi

if ! grep -q "^LIVE:4004:${REPO_REAL}$" <<<"$OUTPUT"; then
  echo "FAIL: pid 4004 (different --add-dir, genuine other session) should be reported LIVE, got: $OUTPUT" >&2
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: self-exclusion by --add-dir match works; genuine other sessions still flagged"
fi

exit "$fail"
