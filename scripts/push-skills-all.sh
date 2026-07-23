#!/usr/bin/env bash
# Bulk-push skill bundles into every repo listed in
# ~/.config/ai-skills/push-targets.json — reuses push-skills.sh's copy+commit
# logic per target. Never pushes (same as push-skills.sh). Never aborts on
# one bad target; reports a summary at the end.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config/ai-skills/push-targets.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "No push targets configured."
  echo "→ copy config/push-targets.template.json to $CONFIG and fill in real paths."
  exit 0
fi

TARGETS="$(CONFIG="$CONFIG" python3 << 'PY'
import json, os, sys

path = os.environ["CONFIG"]
try:
    data = json.loads(open(path).read())
except Exception as e:
    print(f"error: could not parse {path}: {e}", file=sys.stderr)
    sys.exit(1)

for t in data.get("targets", []):
    print(f"{t.get('path', '')}\t{t.get('bundle', 'universal')}")
PY
)"
status=$?

if [[ $status -ne 0 ]]; then
  echo "$TARGETS" >&2
  exit 1
fi

COMMITTED=0
SKIPPED=0
UNREACHABLE=0

while IFS=$'\t' read -r raw_path bundle; do
  [[ -z "$raw_path" ]] && continue
  path="${raw_path/#\~/$HOME}"
  if [[ ! -d "$path/.git" ]]; then
    echo "warn: not a git repo, skipping: $path" >&2
    UNREACHABLE=$((UNREACHABLE + 1))
    continue
  fi
  echo "→ $path ($bundle)"
  out="$(bash "$SCRIPT_DIR/push-skills.sh" "$path" "$bundle" 2>&1)"
  echo "$out" | sed 's/^/    /'
  if grep -q "No changes to commit" <<<"$out"; then
    SKIPPED=$((SKIPPED + 1))
  elif grep -q "Committed skill update" <<<"$out"; then
    COMMITTED=$((COMMITTED + 1))
  else
    UNREACHABLE=$((UNREACHABLE + 1))
  fi
done <<<"$TARGETS"

echo ""
echo "push-skills-all: $COMMITTED committed, $SKIPPED skipped (no changes), $UNREACHABLE unreachable/failed"
