#!/usr/bin/env bash
# Memory sync (default: dry-run) + symlink integrity diagnostic.
#
# Skills/hooks/agents/CLAUDE.md/cursor-rules are per-item symlinks as of
# v2.0.0 (see principles/deployment.md) — they can't diverge from the repo,
# so there's nothing to "sync back" for them. This script now only writes
# memory/, and otherwise just reports whether each known item is correctly
# linked (diagnostic only, never auto-ingests real content it finds).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"
# shellcheck source=lib/link-items.sh
. "$SCRIPT_DIR/lib/link-items.sh"

DRY_RUN=true
APPLY=false
SKILL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; APPLY=false; shift ;;
    --apply) DRY_RUN=false; APPLY=true; shift ;;
    --skill)
      SKILL_FILTER="${2:?--skill requires a skill directory name}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-from-system.sh [--dry-run] [--apply] [--skill NAME]

  Memory: copies ~/.claude/projects/<repo>/memory/ back into ai/claude/memory/
  (whitelist, default dry-run; --apply writes and records last-sync.json).

  Symlink integrity: reports, for every skill/hook/agent/CLAUDE.md/cursor-rule,
  whether ~/.claude/... is correctly linked into this repo. Diagnostic only —
  never writes. If something shows up as a regular file/dir (not a symlink),
  diff it yourself, then `make install-system --force` to relink, or discard it.

  --skill   Limit the integrity check to one skill directory name

  Never touches: local.json, settings.json, CLAUDE.local.md, secrets.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

log() { echo "$*"; }

sync_dir() {
  local sys="$1" repo="$2" label="$3"
  [[ -d "$sys" ]] || return 0
  if [[ -d "$repo" ]] && diff -rq "$sys" "$repo" &>/dev/null 2>&1; then
    return 0
  fi
  if $APPLY; then
    rm -rf "$repo"
    mkdir -p "$(dirname "$repo")"
    cp -R "${sys%/}/" "$repo"
    log "  synced: $label/"
    CHANGED=$((CHANGED + 1))
  else
    log "  would sync: $label/"
    CHANGED=$((CHANGED + 1))
  fi
}

integrity_note() {  # $1=dst $2=label
  local dst="$1" label="$2"
  if is_symlink_into_repo "$dst"; then
    log "  ok: $label"
  elif [[ -L "$dst" ]]; then
    log "  owned elsewhere (foreign symlink, left alone): $label"
  elif [[ -e "$dst" ]]; then
    log "  ⚠ regular file/dir, not a symlink — diff by hand, then make install-system --force: $label"
  else
    log "  not installed (run make install-system): $label"
  fi
}

CHANGED=0

log ""
log "sync-from-system$( $APPLY || echo ' [dry-run]' )"
log ""

log "Memory:"
sync_dir "$MEMORY_DST" "$MEMORY_SRC" "memory"

log ""
log "Symlink integrity:"

if [[ -n "$SKILL_FILTER" ]]; then
  repo_skill="$SKILLS_SRC/$SKILL_FILTER"
  [[ -d "$repo_skill" ]] || { log "error: no repo skill at $repo_skill" >&2; exit 1; }
  integrity_note "$SKILLS_DST/$SKILL_FILTER" "skills/$SKILL_FILTER"
else
  log "  Skills:"
  for repo_skill in "$SKILLS_SRC"/*/; do
    [[ -d "$repo_skill" ]] || continue
    name="$(basename "$repo_skill")"
    integrity_note "$SKILLS_DST/$name" "skills/$name"
  done

  log "  Hooks:"
  for hook in "$HOOKS_SRC"/*.py; do
    [[ -e "$hook" ]] || continue
    base="$(basename "$hook")"
    integrity_note "$HOOKS_DST/$base" "hooks/$base"
  done

  log "  Agents:"
  if [[ -d "$AGENTS_SRC" ]]; then
    shopt -s nullglob
    for agent in "$AGENTS_SRC"/*.md; do
      base="$(basename "$agent")"
      integrity_note "$AGENTS_DST/$base" "agents/$base"
    done
    shopt -u nullglob
  fi

  log "  CLAUDE.md:"
  integrity_note "$CLAUDE_MD_DST" "ai/claude/CLAUDE.md"

  log "  Cursor rules:"
  if [[ -d "$CURSOR_RULES_SRC" ]]; then
    shopt -s nullglob
    for repo_rule in "$CURSOR_RULES_SRC"/*.mdc; do
      base="$(basename "$repo_rule")"
      integrity_note "$CURSOR_RULES_DST/$base" "ai/cursor/rules/$base"
    done
    shopt -u nullglob
  fi
fi

log ""
if [[ "$CHANGED" -eq 0 ]]; then
  log "No memory changes to sync."
elif $APPLY; then
  log "Applied $CHANGED memory change(s). Next: review, make manifest-update, git-ops PR."
  mkdir -p "$(dirname "$LAST_SYNC")"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$LAST_SYNC"
  log "wrote: ${LAST_SYNC#$REPO_DIR/}"
else
  log "$CHANGED memory change(s) would be applied. Re-run with --apply to write repo."
fi
log ""
