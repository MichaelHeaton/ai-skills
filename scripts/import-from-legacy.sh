#!/usr/bin/env bash
# One-time / repeatable import from claude-skills into ai-skills target layout.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_REPO="${LEGACY_REPO:-$REPO_DIR/../claude-skills}"

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

log ""
log "import-from-legacy"
log "  source: $LEGACY_REPO"
log "  target: $REPO_DIR"
log ""

log "1. Claude tree..."
copy_tree "$LEGACY_REPO/skills" "$REPO_DIR/ai/claude/skills"
copy_tree "$LEGACY_REPO/hooks" "$REPO_DIR/ai/claude/hooks"
copy_tree "$LEGACY_REPO/memory" "$REPO_DIR/ai/claude/memory"
copy_tree "$LEGACY_REPO/config/CLAUDE.md" "$REPO_DIR/ai/claude/CLAUDE.md"

log ""
log "2. Config templates..."
mkdir -p "$REPO_DIR/config"
for f in local.template.json accounts.shell.template local.env.template leak-patterns.README; do
  [[ -f "$LEGACY_REPO/config/$f" ]] && cp "$LEGACY_REPO/config/$f" "$REPO_DIR/config/$f" && log "  copied: config/$f"
done

log ""
log "3. Docs guides (from references/)..."
mkdir -p "$REPO_DIR/docs/guides"
for f in local-config.md branching.md formatting.md; do
  [[ -f "$LEGACY_REPO/references/$f" ]] && cp "$LEGACY_REPO/references/$f" "$REPO_DIR/docs/guides/$f" && log "  copied: docs/guides/$f"
done
[[ -f "$LEGACY_REPO/docs/multi-ai.md" ]] && cp "$LEGACY_REPO/docs/multi-ai.md" "$REPO_DIR/docs/multi-ai.md" && log "  copied: docs/multi-ai.md"
[[ -f "$LEGACY_REPO/CONVENTIONS.md" ]] && cp "$LEGACY_REPO/CONVENTIONS.md" "$REPO_DIR/docs/guides/skill-conventions.md" && log "  copied: docs/guides/skill-conventions.md"

log ""
log "4. License..."
[[ -f "$LEGACY_REPO/LICENSE" ]] && cp "$LEGACY_REPO/LICENSE" "$REPO_DIR/LICENSE" && log "  copied: LICENSE"

log ""
log "5. Legacy pre-commit (reference until .pre-commit-config in PR 3)..."
mkdir -p "$REPO_DIR/scripts/hooks"
[[ -f "$LEGACY_REPO/hooks/pre-commit" ]] && cp "$LEGACY_REPO/hooks/pre-commit" "$REPO_DIR/scripts/hooks/legacy-pre-commit" && log "  copied: scripts/hooks/legacy-pre-commit"

log ""
log "Import complete. Next: make bootstrap-version && make manifest-update"
log ""
