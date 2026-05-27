#!/usr/bin/env bash
# Import from claude-skills into ai/claude/ (large change — run only when ready).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_REPO="${LEGACY_REPO:-$REPO_DIR/../claude-skills}"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    -h|--help)
      echo "Usage: import-from-legacy.sh [--force]"
      echo "  Copies ai/claude/* from LEGACY_REPO (default: ../claude-skills)."
      echo "  Does not overwrite config/ or docs/guides/ unless --force."
      exit 0
      ;;
  esac
done

if [[ ! -d "$LEGACY_REPO/skills" ]]; then
  echo "error: legacy repo not found at $LEGACY_REPO" >&2
  exit 1
fi

log() { echo "$*"; }

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    cp -R "$src" "$dst"
    log "  copied: $dst/"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log "  copied: $dst"
  else
    log "  skip (missing): $src"
  fi
}

copy_if_missing() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    log "  skip (missing): $src"
    return
  fi
  if [[ -f "$dst" && "$FORCE" != "true" ]]; then
    log "  skip (exists): $dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log "  copied: $dst"
}

log ""
log "import-from-legacy"
log "  source: $LEGACY_REPO"
log "  target: $REPO_DIR"
log ""

log "1. Claude tree → ai/claude/..."
copy_tree "$LEGACY_REPO/skills" "$REPO_DIR/ai/claude/skills"
copy_tree "$LEGACY_REPO/hooks" "$REPO_DIR/ai/claude/hooks"
copy_tree "$LEGACY_REPO/memory" "$REPO_DIR/ai/claude/memory"
copy_tree "$LEGACY_REPO/config/CLAUDE.md" "$REPO_DIR/ai/claude/CLAUDE.md"

log ""
log "2. Config templates (skip if already in ai-skills)..."
mkdir -p "$REPO_DIR/config"
for f in local.template.json accounts.shell.template local.env.template leak-patterns.README; do
  copy_if_missing "$LEGACY_REPO/config/$f" "$REPO_DIR/config/$f"
done

log ""
log "3. Docs — skipped (ai-skills docs/guides/ is canonical)"

log ""
log "4. Legacy pre-commit reference..."
mkdir -p "$REPO_DIR/scripts/hooks"
if [[ -f "$LEGACY_REPO/hooks/pre-commit" ]]; then
  cp "$LEGACY_REPO/hooks/pre-commit" "$REPO_DIR/scripts/hooks/legacy-pre-commit"
  log "  copied: scripts/hooks/legacy-pre-commit"
fi

log ""
log "5. Materialize skill conventions (no symlinks to legacy repo)..."
GUIDE="$REPO_DIR/docs/guides/skill-conventions.md"
if [[ -f "$GUIDE" ]]; then
  for skill in skill-create skill-review; do
    ref="$REPO_DIR/ai/claude/skills/$skill/references"
    mkdir -p "$ref"
    rm -f "$ref/conventions.md"
    cp "$GUIDE" "$ref/conventions.md"
    log "  copied: $ref/conventions.md"
  done
else
  log "  skip (missing): $GUIDE"
fi

log ""
log "Import complete. Next: make bootstrap-version && make manifest-update"
log ""
