#!/usr/bin/env bash
# Pull allowed ~/.claude/ edits back into ai/claude/ (default: dry-run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

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

  Copies whitelisted paths from ~/.claude/ back into this repo.

  Default: dry-run (shows what would change).
  --apply   Write files into ai/claude/
  --skill   Limit to one skill directory name

  Never syncs: local.json, settings.json, CLAUDE.local.md, secrets.

  After --apply: review diff, bump version fields, run make manifest-update, open PR.
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

sync_file() {
  local sys="$1" repo="$2" label="$3"
  [[ -f "$sys" ]] || return 0
  if [[ -f "$repo" ]] && diff -q "$sys" "$repo" &>/dev/null 2>&1; then
    return 0
  fi
  if $APPLY; then
    mkdir -p "$(dirname "$repo")"
    cp "$sys" "$repo"
    log "  synced: $label"
    CHANGED=$((CHANGED + 1))
  else
    log "  would sync: $label"
    CHANGED=$((CHANGED + 1))
  fi
}

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

CHANGED=0

log ""
log "sync-from-system$( $APPLY || echo ' [dry-run]' )"
log ""

if [[ -n "$SKILL_FILTER" ]]; then
  sys="$SKILLS_DST/$SKILL_FILTER"
  repo="$SKILLS_SRC/$SKILL_FILTER"
  if [[ ! -d "$sys" ]]; then
    log "error: no system skill at $sys" >&2
    exit 1
  fi
  sync_dir "$sys" "$repo" "skills/$SKILL_FILTER"
else
  log "Skills:"
  for sys_skill in "$SKILLS_DST"/*/; do
    [[ -d "$sys_skill" ]] || continue
    name="$(basename "$sys_skill")"
    repo_skill="$SKILLS_SRC/$name"
    [[ -d "$repo_skill" ]] || continue
    sync_dir "$sys_skill" "$repo_skill" "skills/$name"
  done

  log ""
  log "Hooks:"
  for hook in "$HOOKS_DST"/*.py; do
    [[ -f "$hook" ]] || continue
    base="$(basename "$hook")"
    sync_file "$hook" "$HOOKS_SRC/$base" "hooks/$base"
  done

  log ""
  log "CLAUDE.md:"
  sync_file "$CLAUDE_MD_DST" "$CLAUDE_MD_SRC" "ai/claude/CLAUDE.md"

  log ""
  log "Memory:"
  sync_dir "$MEMORY_DST" "$MEMORY_SRC" "memory"
fi

log ""
if [[ "$CHANGED" -eq 0 ]]; then
  log "No changes to sync."
elif $APPLY; then
  log "Applied $CHANGED change(s). Next: review, make manifest-update, git-ops PR."
  mkdir -p "$(dirname "$LAST_SYNC")"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$LAST_SYNC"
  log "wrote: ${LAST_SYNC#$REPO_DIR/}"
else
  log "$CHANGED change(s) would be applied. Re-run with --apply to write repo."
fi
log ""
