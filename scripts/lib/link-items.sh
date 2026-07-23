# Shared per-item symlink helpers for install-system.sh / reconcile-symlinks.sh.
# Source after lib/deploy-paths.sh (needs $REPO_DIR). Callers must define
# DRY_RUN and FORCE before calling link_item/remove_retired.
#
# Core invariant: this repo's tooling only ever creates a symlink where
# nothing exists, or touches a symlink that already resolves inside this
# repo. A real file/dir, or a symlink pointing elsewhere, is permanently
# hands-off — --force only overrides our own differing content, never
# something we don't own.

log() { echo "$*"; }

resolve() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}

is_symlink_into_repo() {
  local dst="$1"
  [[ -L "$dst" ]] || return 1
  local target
  target="$(resolve "$dst")"
  [[ -n "$target" && "$target" == "$REPO_DIR"/* ]]
}

content_matches() {  # $1=src $2=dst $3=file|dir
  if [[ "$3" == dir ]]; then
    diff -rq "$1" "$2" &>/dev/null
  else
    diff -q "$1" "$2" &>/dev/null
  fi
}

# Pre-flight, read-only: appends a note to the global UNSYNCED array for any
# real (non-symlink) destination whose content differs from the repo source.
# Never mutates anything on disk.
scan_unsynced() {
  local src="$1" dst="$2" label="$3" kind="$4"
  [[ -e "$src" && -e "$dst" && ! -L "$dst" ]] || return 0
  content_matches "$src" "$dst" "$kind" && return 0
  local hint="not newer than repo"
  [[ "$dst" -nt "$src" ]] && hint="newer than repo — possible unsynced edit"
  UNSYNCED+=("$label ($hint)")
}

# Create, relink, or skip one item. Requires $DRY_RUN and $FORCE to be set.
link_item() {
  local src="$1" dst="$2" label="$3" kind="$4"
  [[ -e "$src" ]] || { log "skip (missing source): $label"; return; }

  if [[ -L "$dst" ]]; then
    if [[ "$(resolve "$dst")" == "$(resolve "$src")" ]]; then
      log "ok: $label"
      return
    fi
    if is_symlink_into_repo "$dst"; then
      if $DRY_RUN; then log "  → relink (stale target): $label"; return; fi
      ln -sfn "$src" "$dst"
      log "relinked: $label"
      return
    fi
    log "skip (symlink points outside this repo -> $(resolve "$dst")): $label"
    return
  fi

  if [[ -e "$dst" ]]; then
    if content_matches "$src" "$dst" "$kind"; then
      if $DRY_RUN; then log "  → link (replace identical copy): $label"; return; fi
      rm -rf "$dst"
      mkdir -p "$(dirname "$dst")"
      ln -s "$src" "$dst"
      log "linked (replaced identical legacy copy): $label"
      return
    fi
    if $FORCE; then
      if $DRY_RUN; then log "  → link --force (replace differing content): $label"; return; fi
      rm -rf "$dst"
      mkdir -p "$(dirname "$dst")"
      ln -s "$src" "$dst"
      log "linked (--force, replaced differing content): $label"
      return
    fi
    log "  → needs --force (differs from repo, not a symlink): $label"
    return
  fi

  if $DRY_RUN; then log "  → link (new): $label"; return; fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "linked (new): $label"
}

# Remove a symlink for a retired item — only if this repo owns it.
remove_retired() {
  local dst="$1" label="$2"
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    log "skip (not installed): $label"
    return
  fi
  if is_symlink_into_repo "$dst"; then
    if $DRY_RUN; then log "  → remove: $label"; return; fi
    rm -f "$dst"
    log "removed: $label"
  elif [[ -L "$dst" ]]; then
    log "skip (symlink owned elsewhere, leaving in place): $label"
  else
    log "skip (real content, not ours — leaving in place): $label"
  fi
}
