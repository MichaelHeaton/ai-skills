#!/usr/bin/env bash
# Detects what this environment actually has available, so a calling skill can
# route to a working fallback instead of failing mid-step on a missing tool or
# an absent local clone. Read-only, advisory — never modifies anything, never
# exits non-zero on a missing capability.
#
# Usage: env-capability-check.sh [skill-name ...]
#   With no args: prints the fixed set of checks below.
#   With one or more skill names: also prints a DEPLOYED line per name.
#
# Output (one line per check, always present even when the answer is "no"):
#   GH_CLI:present:authenticated   | GH_CLI:present:unauthenticated | GH_CLI:absent
#   GLAB_CLI:present               | GLAB_CLI:absent
#   LOCAL_CONFIG:present:<path>    | LOCAL_CONFIG:absent
#   MEMEX_VAULT:present:<path>     | MEMEX_VAULT:absent
#   DEPLOYED:<skill-name>:yes      | DEPLOYED:<skill-name>:no   (one per arg)
#
# Exits 0 always — this is advisory, consult the output, never a hard gate.

if command -v gh >/dev/null 2>&1; then
  if gh auth token >/dev/null 2>&1; then
    echo "GH_CLI:present:authenticated"
  else
    echo "GH_CLI:present:unauthenticated"
  fi
else
  echo "GH_CLI:absent"
fi

if command -v glab >/dev/null 2>&1; then
  echo "GLAB_CLI:present"
else
  echo "GLAB_CLI:absent"
fi

LOCAL_CONFIG="$HOME/.config/ai-skills/local.json"
if [[ -f "$LOCAL_CONFIG" ]]; then
  echo "LOCAL_CONFIG:present:$LOCAL_CONFIG"
else
  echo "LOCAL_CONFIG:absent"
fi

MEMEX_ROOT="$HOME/Projects/personal/memex"
if [[ -d "$MEMEX_ROOT/Raw" ]]; then
  echo "MEMEX_VAULT:present:$MEMEX_ROOT"
else
  echo "MEMEX_VAULT:absent"
fi

for name in "$@"; do
  if [[ -e "$HOME/.claude/skills/$name/SKILL.md" ]]; then
    echo "DEPLOYED:$name:yes"
  else
    echo "DEPLOYED:$name:no"
  fi
done

exit 0
