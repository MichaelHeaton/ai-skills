#!/usr/bin/env bash
# Copy-only deploy: ai/claude/ → ~/.claude/ (and related paths). No symlinks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

DRY_RUN=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: install-system.sh [--dry-run] [--force]

  Deploys ai/claude/ to ~/.claude/ and ai/cursor/rules/*.mdc to ~/.cursor/rules/ (copy only).

  --dry-run  Show what would change
  --force    Install even if system files look newer than repo (unsynced edits)

  After install: run from this repo when skills change. Prefer editing the repo,
  then install-system. Use sync-from-system if you edited under ~/.claude/ first.
EOF
      exit 0
      ;;
  esac
done

log() { echo "$*"; }

install_file() {
  local src="$1" dst="$2" label="${3:-$(basename "$dst")}"
  [[ -e "$src" ]] || { log "skip (missing source): $label"; return; }

  if [[ -L "$dst" ]]; then
    if $DRY_RUN; then log "  → replace symlink with copy: $label"; return; fi
    rm -f "$dst"
  elif [[ -f "$dst" ]] && diff -q "$src" "$dst" &>/dev/null 2>&1; then
    log "skip (up to date): $label"
    return
  fi

  if $DRY_RUN; then
    log "  → copy: $label"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log "copied: $label"
}

install_dir() {
  local src="$1" dst="$2" label="${3:-$(basename "$dst")}"
  [[ -d "$src" ]] || { log "skip (missing source): $label/"; return; }

  if [[ -L "$dst" ]]; then
    if $DRY_RUN; then log "  → replace symlink with copy: $label/"; return; fi
    rm -rf "$dst"
  elif [[ -d "$dst" ]] && diff -rq "$src" "$dst" &>/dev/null 2>&1; then
    log "skip (up to date): $label/"
    return
  fi

  if $DRY_RUN; then
    log "  → copy: $label/"
    return
  fi
  rm -rf "$dst" 2>/dev/null || true
  cp -R "${src%/}/" "$dst"
  log "copied: $label/"
}

check_unsynced() {
  if $FORCE || $DRY_RUN; then
    return 0
  fi
  if [[ ! -d "$SKILLS_DST" ]]; then
    return 0
  fi
  local found=false
  while IFS= read -r skill_dir; do
    local skill repo_skill sys rep
    skill="$(basename "$skill_dir")"
    repo_skill="$SKILLS_SRC/$skill"
    [[ -d "$repo_skill" ]] || continue
    local sys="$SKILLS_DST/$skill/SKILL.md" rep="$repo_skill/SKILL.md"
    [[ -f "$sys" && -f "$rep" ]] || continue
    if ! diff -q "$sys" "$rep" &>/dev/null && [[ "$sys" -nt "$rep" ]]; then
      log "warning: ~/.claude/skills/$skill differs from repo and looks newer on disk"
      log "  → run: make sync-from-system   (or make install-system --force)"
      found=true
    fi
  done < <(find "$SKILLS_DST" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  if $found; then
    log ""
    log "Aborting install (use --force to overwrite unsynced system edits)."
    exit 1
  fi
}

write_system_manifest() {
  $DRY_RUN && return 0
  export REPO_DIR SYSTEM_MANIFEST
  python3 << 'PY'
import hashlib, json, os
from pathlib import Path

repo = Path(os.environ["REPO_DIR"])
out = Path(os.environ["SYSTEM_MANIFEST"])
paths = {}

def add(p: Path):
    if p.is_file():
        rel = p.relative_to(repo).as_posix()
        paths[rel] = hashlib.md5(p.read_bytes()).hexdigest()

claude = repo / "ai" / "claude"
for sub in ("skills", "hooks", "memory"):
    root = claude / sub
    if root.is_dir():
        for f in root.rglob("*"):
            if f.is_file():
                add(f)
cm = claude / "CLAUDE.md"
if cm.is_file():
    add(cm)

cursor_rules = repo / "ai" / "cursor" / "rules"
if cursor_rules.is_dir():
    for f in cursor_rules.glob("*.mdc"):
        if f.is_file():
            add(f)

out.parent.mkdir(parents=True, exist_ok=True)
payload = {
    "generated_at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "algorithm": "md5",
    "scope": "system-deploy",
    "paths": dict(sorted(paths.items())),
}
out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
  log "wrote: ${SYSTEM_MANIFEST#$REPO_DIR/}"
}

if [[ ! -d "$SKILLS_SRC" ]]; then
  log "error: $SKILLS_SRC not found — import skills first" >&2
  exit 1
fi

log ""
log "install-system$( $DRY_RUN && echo ' [dry-run]' )"
log "  repo:   $REPO_DIR"
log "  target: $SKILLS_DST"
log ""

check_unsynced

if ! $DRY_RUN; then
  mkdir -p "$SKILLS_DST" "$HOOKS_DST" "$HOME/.local/bin" "$HOME/.claude/logs" "$CONFIG_DST_DIR" "$CURSOR_RULES_DST"
  mkdir -p "$(dirname "$MEMORY_DST")"
fi

log "1. Skills"
for skill_dir in "$SKILLS_SRC"/*/; do
  skill="$(basename "$skill_dir")"
  install_dir "$skill_dir" "$SKILLS_DST/$skill" "$skill"
done

log ""
log "2. Retired skills (remove from system)"
for retired in "${RETIRED_SKILLS[@]}"; do
  dst="$SKILLS_DST/$retired"
  if [[ -e "$dst" ]]; then
    if $DRY_RUN; then
      log "  → remove: $retired"
    else
      rm -rf "$dst"
      log "  removed: $retired"
    fi
  else
    log "  skip (not installed): $retired"
  fi
done

log ""
log "3. Hooks (*.py)"
for hook in "$HOOKS_SRC"/*.py; do
  [[ -e "$hook" ]] || continue
  install_file "$hook" "$HOOKS_DST/$(basename "$hook")" "hook: $(basename "$hook")"
done

log ""
log "4. CLAUDE.md (formatting overlay)"
install_file "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST" "CLAUDE.md"

log ""
log "5. Cursor rules (*.mdc)"
if [[ -d "$CURSOR_RULES_SRC" ]]; then
  shopt -s nullglob
  rules=("$CURSOR_RULES_SRC"/*.mdc)
  shopt -u nullglob
  if [[ ${#rules[@]} -eq 0 ]]; then
    log "skip (no .mdc files): ai/cursor/rules/"
  else
    for rule in "${rules[@]}"; do
      base="$(basename "$rule")"
      install_file "$rule" "$CURSOR_RULES_DST/$base" "cursor: $base"
    done
  fi
else
  log "skip (missing source): ai/cursor/rules/"
fi

log ""
log "5b. Retired Cursor rules"
for retired in "${RETIRED_CURSOR_RULES[@]}"; do
  dst="$CURSOR_RULES_DST/$retired"
  [[ -e "$dst" ]] || continue
  if $DRY_RUN; then
    log "  → remove: $retired"
  else
    rm -f "$dst"
    log "  removed: $retired"
  fi
done

log ""
log "6. Memory (copy to project path)"
install_dir "$MEMORY_SRC" "$MEMORY_DST" "memory"

log ""
log "7. clog"
[[ -f "$CLOG_SRC" ]] && { $DRY_RUN || chmod +x "$CLOG_SRC"; install_file "$CLOG_SRC" "$CLOG_DST" "clog"; }

log ""
log "8. Private config (create-if-missing)"
if [[ -f "$CONFIG_DST" ]]; then
  log "skip (exists): $CONFIG_DST"
elif [[ -f "$CONFIG_TEMPLATE" ]]; then
  if $DRY_RUN; then
    log "  → create: $CONFIG_DST from template"
  else
    cp "$CONFIG_TEMPLATE" "$CONFIG_DST"
    log "created: $CONFIG_DST (fill in — never commit)"
  fi
else
  log "skip (no template): $CONFIG_TEMPLATE"
fi

log ""
if $DRY_RUN; then
  log "Dry run complete."
else
  count="$(find "$SKILLS_DST" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  write_system_manifest
  log "Done. $count skills in $SKILLS_DST"
  log "Reload Claude Code (new conversation) to pick up changes."
fi
log ""
