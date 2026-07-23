#!/usr/bin/env bash
# Record that a skill's current version was manually uploaded to Claude
# Desktop / claude.ai, so `make status` can later flag it as stale once the
# skill changes again. Usage: mark-uploaded.sh --skill NAME | --bundle NAME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

STATE_FILE="$REPO_DIR/.deploy/desktop-upload-state.json"
SKILL_SETS="$REPO_DIR/skill-sets"

MODE=""
NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) MODE="skill"; NAME="${2:?--skill requires a name}"; shift 2 ;;
    --bundle) MODE="bundle"; NAME="${2:?--bundle requires a name}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$MODE" ]] || { echo "Usage: mark-uploaded.sh --skill NAME | --bundle NAME" >&2; exit 1; }

if [[ "$MODE" == "skill" ]]; then
  SKILLS="$NAME"
else
  bundle_file="$SKILL_SETS/${NAME}.txt"
  [[ -f "$bundle_file" ]] || { echo "Bundle '$NAME' not found." >&2; exit 1; }
  SKILLS="$(grep -v '^#' "$bundle_file" | grep -v '^$' | tr -d ' ')"
fi

for skill in $SKILLS; do
  [[ -d "$SKILLS_SRC/$skill" ]] || { echo "skip (not found): $skill" >&2; continue; }
  SKILL="$skill" SKILLS_SRC="$SKILLS_SRC" STATE_FILE="$STATE_FILE" python3 << 'PY'
import json, os
from datetime import datetime, timezone
from pathlib import Path

skill = os.environ["SKILL"]
skills_src = Path(os.environ["SKILLS_SRC"])
state_path = Path(os.environ["STATE_FILE"])

skill_md = skills_src / skill / "SKILL.md"
version = "0.0.0"
if skill_md.is_file():
    for line in skill_md.read_text().splitlines():
        if line.startswith("version:"):
            version = line.split(":", 1)[1].strip()
            break

state = {"updated_at": "", "skills": {}}
if state_path.is_file():
    try:
        state = json.loads(state_path.read_text())
    except Exception:
        pass
state.setdefault("skills", {})

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
state["skills"][skill] = {"version": version, "uploaded_at": now}
state["updated_at"] = now

state_path.parent.mkdir(parents=True, exist_ok=True)
state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(f"recorded: {skill} v{version}")
PY
done

echo ""
echo "Commit .deploy/desktop-upload-state.json so other machines see this upload."
