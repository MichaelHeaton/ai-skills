#!/usr/bin/env bash
# Pull allowed ~/.claude/ edits back into ai/claude/ (default: dry-run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

DRY_RUN=true
APPLY=false
FORCE=false
SKILL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; APPLY=false; shift ;;
    --apply) DRY_RUN=false; APPLY=true; shift ;;
    --force) FORCE=true; shift ;;
    --skill)
      SKILL_FILTER="${2:?--skill requires a skill directory name}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-from-system.sh [--dry-run] [--apply] [--force] [--skill NAME]

  Copies whitelisted paths from ~/.claude/ and repo-managed ~/.cursor/rules/*.mdc back into this repo.

  Default: dry-run (shows what would change).
  --apply   Write files into ai/claude/
  --force   Apply even when local skill version is older than repo version
  --skill   Limit to one skill directory name

  Never syncs: local.json, settings.json, CLAUDE.local.md, secrets.

  Skills where local version < repo version are skipped by default (downgrade protection).
  Use --force to override.

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

get_version() {
  local skill_md="$1/SKILL.md"
  [[ -f "$skill_md" ]] || { echo "0.0.0"; return; }
  grep -m1 '^version:' "$skill_md" | awk '{print $2}' || echo "0.0.0"
}

version_lt() {
  [[ "$1" == "$2" ]] && return 1
  [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

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
  local_ver="$(get_version "$sys")"
  repo_ver="$(get_version "$repo")"
  if version_lt "$local_ver" "$repo_ver"; then
    if $FORCE; then
      log "  ⚠️  skills/$SKILL_FILTER — local v${local_ver} < repo v${repo_ver} (--force: applying anyway)"
    else
      log "  ⚠️  skills/$SKILL_FILTER — local v${local_ver} < repo v${repo_ver} (local is OLDER — skipping to avoid downgrade)"
      log "  → Re-run with --force to override."
      exit 0
    fi
  fi
  sync_dir "$sys" "$repo" "skills/$SKILL_FILTER"
else
  log "Skills:"
  for sys_skill in "$SKILLS_DST"/*/; do
    [[ -d "$sys_skill" ]] || continue
    name="$(basename "$sys_skill")"
    repo_skill="$SKILLS_SRC/$name"
    [[ -d "$repo_skill" ]] || continue
    local_ver="$(get_version "$sys_skill")"
    repo_ver="$(get_version "$repo_skill")"
    if version_lt "$local_ver" "$repo_ver"; then
      if $FORCE; then
        log "  ⚠️  skills/$name — local v${local_ver} < repo v${repo_ver} (--force: applying anyway)"
      else
        if $APPLY; then
          log "  ⚠️  skills/$name — local v${local_ver} < repo v${repo_ver} (local is OLDER — skipping to avoid downgrade)"
        else
          log "  ⚠️  skills/$name — local v${local_ver} < repo v${repo_ver} (local is OLDER — would skip to avoid downgrade)"
        fi
        continue
      fi
    fi
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
  log "Cursor rules:"
  if [[ -d "$CURSOR_RULES_SRC" ]]; then
    shopt -s nullglob
    for repo_rule in "$CURSOR_RULES_SRC"/*.mdc; do
      base="$(basename "$repo_rule")"
      sync_file "$CURSOR_RULES_DST/$base" "$repo_rule" "ai/cursor/rules/$base"
    done
    shopt -u nullglob
  else
    log "  skip (missing repo path): ai/cursor/rules/"
  fi

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
