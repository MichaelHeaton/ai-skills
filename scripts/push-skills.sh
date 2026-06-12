#!/usr/bin/env bash
# Push a skill bundle from ai-skills into another repo's .claude/skills/.
# Usage: bash scripts/push-skills.sh <project-path> [bundle]
# Example: bash scripts/push-skills.sh ~/code/my-sre-repo sre
set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "$0")/.." && pwd)/ai/claude/skills"
SKILL_SETS="$(cd "$(dirname "$0")/.." && pwd)/skill-sets"

PROJECT="${1:-}"
BUNDLE="${2:-universal}"

# ── validation ────────────────────────────────────────────────────────────────

if [[ -z "$PROJECT" ]]; then
  echo "Usage: bash scripts/push-skills.sh <project-path> [bundle]" >&2
  echo "Bundles available:" >&2
  ls "$SKILL_SETS"/*.txt | xargs -n1 basename | sed 's/\.txt$//' | sed 's/^/  /' >&2
  exit 1
fi

PROJECT="$(cd "$PROJECT" && pwd)"
BUNDLE_FILE="$SKILL_SETS/${BUNDLE}.txt"

if [[ ! -f "$BUNDLE_FILE" ]]; then
  echo "Bundle '$BUNDLE' not found. Available bundles:" >&2
  ls "$SKILL_SETS"/*.txt | xargs -n1 basename | sed 's/\.txt$//' | sed 's/^/  /' >&2
  exit 1
fi

if [[ ! -d "$PROJECT/.git" ]]; then
  echo "Not a git repo: $PROJECT" >&2
  exit 1
fi

# ── copy skills ───────────────────────────────────────────────────────────────

DEST="$PROJECT/.claude/skills"
mkdir -p "$DEST"

COPIED=()
SKIPPED=()

while IFS= read -r line; do
  # strip comments and blank lines
  skill="${line%%#*}"
  skill="${skill// /}"
  [[ -z "$skill" ]] && continue

  src="$SKILLS_SRC/$skill"
  if [[ ! -d "$src" ]]; then
    echo "  warn: skill '$skill' not found in source, skipping" >&2
    SKIPPED+=("$skill")
    continue
  fi

  rsync -a --delete "$src/" "$DEST/$skill/"
  COPIED+=("$skill")
done < "$BUNDLE_FILE"

echo "Copied ${#COPIED[@]} skills to $DEST"
[[ ${#SKIPPED[@]} -gt 0 ]] && echo "Skipped (not found): ${SKIPPED[*]}"

# ── commit in target repo ─────────────────────────────────────────────────────

cd "$PROJECT"

if git diff --quiet HEAD -- .claude/skills/ 2>/dev/null && \
   [[ -z "$(git ls-files --others --exclude-standard .claude/skills/)" ]]; then
  echo "No changes to commit in $PROJECT"
  exit 0
fi

SOURCE_REPO="$(basename "$(cd "$(dirname "$0")/.." && pwd)")"
git add .claude/skills/
git commit -m "chore: sync ${BUNDLE} skill bundle from ${SOURCE_REPO}"
echo "Committed skill update in $PROJECT"
echo ""
echo "Push when ready: git push  (from $PROJECT)"
