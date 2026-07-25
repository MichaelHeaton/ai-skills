#!/usr/bin/env bash
# Build a folder-at-root zip for manual upload to Claude Desktop / claude.ai
# (Settings > Skills > Upload requires the skill's folder, not a loose
# SKILL.md, at the zip root — there is no upload API for personal accounts).
# Usage: package-skill.sh --skill NAME | --bundle NAME | --all [--batch-size N]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

OUT_DIR="$REPO_DIR/.deploy/packages"
SKILL_SETS="$REPO_DIR/skill-sets"
# claude.ai's Upload skill dialog rejects a batch of more than 20 files at once.
BATCH_SIZE="${BATCH_SIZE:-20}"
# claude.ai rejects a SKILL.md description over this many characters.
DESC_LIMIT=1024

MODE=""
NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) MODE="skill"; NAME="${2:?--skill requires a name}"; shift 2 ;;
    --bundle) MODE="bundle"; NAME="${2:?--bundle requires a name}"; shift 2 ;;
    --all) MODE="all"; shift ;;
    --batch-size) BATCH_SIZE="${2:?--batch-size requires a number}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$MODE" ]] || { echo "Usage: package-skill.sh --skill NAME | --bundle NAME | --all [--batch-size N]" >&2; exit 1; }

get_version() {
  local skill_md="$SKILLS_SRC/$1/SKILL.md"
  [[ -f "$skill_md" ]] || { echo "0.0.0"; return; }
  grep -m1 '^version:' "$skill_md" | awk '{print $2}' || echo "0.0.0"
}

# Extracts the raw description field (single physical line in this repo's
# frontmatter convention) and checks it against claude.ai's upload limit.
check_description() {
  local name="$1"
  local skill_md="$SKILLS_SRC/$name/SKILL.md"
  [[ -f "$skill_md" ]] || return 0
  local line desc len
  line="$(grep -m1 '^description:' "$skill_md" || true)"
  [[ -n "$line" ]] || return 0
  desc="${line#description: }"
  desc="${desc%\"}"
  desc="${desc#\"}"
  len="${#desc}"
  if (( len > DESC_LIMIT )); then
    echo "ERROR: $name — description is $len chars (limit $DESC_LIMIT). Trim SKILL.md before packaging." >&2
    return 1
  fi
}

package_one() {
  local name="$1"
  local dest_dir="${2:-$OUT_DIR}"
  local src="$SKILLS_SRC/$name"
  [[ -d "$src" ]] || { echo "skip (not found): $name" >&2; return; }
  check_description "$name" || { FAILED+=("$name"); return; }
  local version out
  version="$(get_version "$name")"
  out="$dest_dir/${name}-${version}.zip"
  mkdir -p "$dest_dir"
  rm -f "$out"
  (cd "$SKILLS_SRC" && zip -rq "$out" "$name")
  echo "packaged: $out"
  PACKAGED+=("$name")
}

PACKAGED=()
FAILED=()

if [[ "$MODE" == "skill" ]]; then
  package_one "$NAME"
elif [[ "$MODE" == "bundle" ]]; then
  bundle_file="$SKILL_SETS/${NAME}.txt"
  [[ -f "$bundle_file" ]] || { echo "Bundle '$NAME' not found." >&2; exit 1; }
  while IFS= read -r line; do
    skill="${line%%#*}"
    skill="${skill// /}"
    [[ -z "$skill" ]] && continue
    package_one "$skill"
  done < "$bundle_file"
else
  # --all: every skill under ai/claude/skills/, chunked into batch-NN/
  # subfolders of at most BATCH_SIZE zips so each folder can be uploaded
  # to claude.ai in one pass without hitting the attachment-count limit.
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  names=()
  for d in "$SKILLS_SRC"/*/; do
    names+=("$(basename "$d")")
  done

  i=0
  batch=1
  batch_dir=""
  for name in "${names[@]}"; do
    if (( i % BATCH_SIZE == 0 )); then
      batch_dir="$OUT_DIR/$(printf 'batch-%02d' "$batch")"
      batch=$((batch + 1))
    fi
    package_one "$name" "$batch_dir"
    i=$((i + 1))
  done

  echo ""
  echo "Packaged ${#PACKAGED[@]} skill(s) into $(( (batch - 1) )) batch folder(s) under $OUT_DIR (max $BATCH_SIZE per batch)."
fi

if (( ${#FAILED[@]} > 0 )); then
  echo ""
  echo "Skipped ${#FAILED[@]} skill(s) due to validation errors: ${FAILED[*]}" >&2
  exit 1
fi
