#!/usr/bin/env bash
# Build a folder-at-root zip for manual upload to Claude Desktop / claude.ai
# (Settings > Skills > Upload requires the skill's folder, not a loose
# SKILL.md, at the zip root — there is no upload API for personal accounts).
# Usage: package-skill.sh --skill NAME | --bundle NAME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

OUT_DIR="$REPO_DIR/.deploy/packages"
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

[[ -n "$MODE" ]] || { echo "Usage: package-skill.sh --skill NAME | --bundle NAME" >&2; exit 1; }

get_version() {
  local skill_md="$SKILLS_SRC/$1/SKILL.md"
  [[ -f "$skill_md" ]] || { echo "0.0.0"; return; }
  grep -m1 '^version:' "$skill_md" | awk '{print $2}' || echo "0.0.0"
}

package_one() {
  local name="$1"
  local src="$SKILLS_SRC/$name"
  [[ -d "$src" ]] || { echo "skip (not found): $name" >&2; return; }
  local version out
  version="$(get_version "$name")"
  out="$OUT_DIR/${name}-${version}.zip"
  mkdir -p "$OUT_DIR"
  rm -f "$out"
  (cd "$SKILLS_SRC" && zip -rq "$out" "$name")
  echo "packaged: $out"
}

if [[ "$MODE" == "skill" ]]; then
  package_one "$NAME"
else
  bundle_file="$SKILL_SETS/${NAME}.txt"
  [[ -f "$bundle_file" ]] || { echo "Bundle '$NAME' not found." >&2; exit 1; }
  while IFS= read -r line; do
    skill="${line%%#*}"
    skill="${skill// /}"
    [[ -z "$skill" ]] && continue
    package_one "$skill"
  done < "$bundle_file"
fi
