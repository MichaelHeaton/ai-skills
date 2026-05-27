#!/usr/bin/env bash
# Phase 0: remove deploy symlinks, materialize copies, migrate config to ~/.config/ai-skills.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_REPO="${LEGACY_REPO:-$REPO_DIR/../claude-skills}"
SKILLS_SRC="$LEGACY_REPO/skills"
SKILLS_DST="$HOME/.claude/skills"
OLD_CONFIG="$HOME/.config/claude-skills"
NEW_CONFIG="$HOME/.config/ai-skills"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: unlink-legacy.sh [--dry-run]"
      echo "  LEGACY_REPO  path to claude-skills (default: ../claude-skills)"
      exit 0
      ;;
  esac
done

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  → $*"
  else
    "$@"
  fi
}

log() { echo "$*"; }

if [[ ! -d "$LEGACY_REPO/skills" ]]; then
  echo "error: legacy skills not found at $LEGACY_REPO/skills" >&2
  exit 1
fi

log ""
log "ai-skills Phase 0: unlink-legacy$( [[ "$DRY_RUN" == "true" ]] && echo " [dry-run]" )"
log "  legacy repo: $LEGACY_REPO"
log ""

log "1. Materialize skill reference symlinks in legacy repo..."
for skill in skill-create skill-review; do
  ref="$LEGACY_REPO/skills/$skill/references/conventions.md"
  if [[ -L "$ref" ]]; then
    target="$(readlink "$ref")"
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → replace symlink: $ref"
    else
      rm "$ref"
      cp "$target" "$ref"
      log "  copied: $skill/references/conventions.md"
    fi
  else
    log "  skip (not a symlink): $skill/references/conventions.md"
  fi
done

log ""
log "2. Materialize ~/.claude/skills..."
if [[ "$DRY_RUN" == "false" ]]; then
  mkdir -p "$SKILLS_DST"
fi

for skill_dir in "$SKILLS_SRC"/*/; do
  skill="$(basename "$skill_dir")"
  dst="$SKILLS_DST/$skill"

  if [[ -L "$dst" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → symlink→copy: $skill"
    else
      rm "$dst"
      cp -R "${skill_dir%/}" "$dst"
      log "  copied: $skill (was symlink)"
    fi
  elif [[ -d "$dst" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → refresh: $skill"
    else
      rm -rf "$dst"
      cp -R "${skill_dir%/}" "$dst"
      log "  refreshed: $skill"
    fi
  else
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → copy new: $skill"
    else
      cp -R "${skill_dir%/}" "$dst"
      log "  copied: $skill (new)"
    fi
  fi
done

for retired in uv-weekly; do
  if [[ -e "$SKILLS_DST/$retired" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → remove retired: $retired"
    else
      rm -rf "$SKILLS_DST/$retired"
      log "  removed retired: $retired"
    fi
  fi
done

log ""
log "3. Materialize claude-skills project memory..."
MEMORY_SRC="$LEGACY_REPO/memory"
for encoded in \
  "-Users-michaelheaton-Projects-personal-claude-skills" \
  "Users-michaelheaton-Projects-personal-claude-skills"; do
  mem_dst="$HOME/.claude/projects/$encoded/memory"
  if [[ -L "$mem_dst" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "  → memory symlink→copy: $encoded"
    else
      rm "$mem_dst"
      cp -R "$MEMORY_SRC" "$mem_dst"
      log "  copied: projects/$encoded/memory"
    fi
  elif [[ -d "$mem_dst" ]]; then
    log "  skip (already a directory): $encoded"
  else
    log "  skip (missing): $encoded"
  fi
done

log ""
log "4. Pre-commit hook in legacy repo..."
HOOK_SRC="$LEGACY_REPO/hooks/pre-commit"
HOOK_DST="$LEGACY_REPO/.git/hooks/pre-commit"
if [[ -L "$HOOK_DST" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  → pre-commit symlink→copy"
  else
    rm "$HOOK_DST"
    cp "$HOOK_SRC" "$HOOK_DST"
    chmod +x "$HOOK_DST"
    log "  copied: .git/hooks/pre-commit"
  fi
elif [[ -f "$HOOK_DST" ]]; then
  log "  skip (regular file already)"
else
  log "  skip (no hook at $HOOK_DST)"
fi

log ""
log "5. Migrate config dir..."
if [[ -d "$OLD_CONFIG" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  → migrate $OLD_CONFIG → $NEW_CONFIG"
  else
    mkdir -p "$NEW_CONFIG"
    for f in local.json accounts.shell leak-patterns install_mode; do
      if [[ -f "$OLD_CONFIG/$f" && ! -e "$NEW_CONFIG/$f" ]]; then
        cp "$OLD_CONFIG/$f" "$NEW_CONFIG/$f"
        log "  copied: $f"
      elif [[ -f "$NEW_CONFIG/$f" ]]; then
        log "  skip (exists in ai-skills): $f"
      fi
    done
    log "  note: old config kept at $OLD_CONFIG (remove manually when satisfied)"
  fi
elif [[ -d "$NEW_CONFIG" ]]; then
  log "  skip (ai-skills config already exists)"
else
  log "  skip (no claude-skills config to migrate)"
fi

log ""
log "6. Verify..."
if [[ "$DRY_RUN" == "false" ]]; then
  skill_links="$(find "$SKILLS_DST" -type l 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$skill_links" != "0" ]]; then
    log "  warning: $skill_links symlink(s) remain under ~/.claude/skills:"
    find "$SKILLS_DST" -type l 2>/dev/null | sed 's/^/    /'
  else
    log "  ok: no symlinks under ~/.claude/skills"
  fi
fi

log ""
if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run complete. Re-run without --dry-run to apply."
else
  log "Phase 0 complete."
  log "  Next: PR 1 in ai-skills (import-from-legacy + scaffold)"
fi
log ""
