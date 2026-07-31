#!/usr/bin/env bash
# Symlink-only deploy: ai/claude/ -> ~/.claude/ (and related paths), per item.
# Each skill/hook/agent/rule/CLAUDE.md is its own symlink into this repo —
# never a whole-directory symlink, never a copy. See principles/deployment.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"
# shellcheck source=lib/link-items.sh
. "$SCRIPT_DIR/lib/link-items.sh"

DRY_RUN=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: install-system.sh [--dry-run] [--force]

  Deploys ai/claude/ to ~/.claude/ and ai/cursor/rules/*.mdc to ~/.cursor/rules/
  as per-item symlinks (skills, hooks, agents, CLAUDE.md, cursor rules).
  memory/ and local.json remain copies — see principles/deployment.md.

  --dry-run  Show what would change
  --force    Link even if a real (non-symlink) destination differs from the
             repo (an unsynced edit made directly under ~/.claude/)

  After install: run from this repo when items are added or retired.
  Existing symlinked items update live via `git pull` — no redeploy needed.
  Use `make sync-from-system` if you edited under ~/.claude/ first.
EOF
      exit 0
      ;;
  esac
done

install_dir() {  # kept only for memory/ — a genuine copy, not a symlink
  local src="$1" dst="$2" label="${3:-$(basename "$dst")}"
  [[ -d "$src" ]] || { log "skip (missing source): $label/"; return; }

  if [[ -L "$dst" ]]; then
    if $DRY_RUN; then log "  → replace symlink with copy: $label/"; return; fi
    rm -f "$dst"
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
for sub in ("skills", "hooks", "memory", "agents"):
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

# ── pre-flight: scan every category for real, differing destinations ───────
UNSYNCED=()

for skill_dir in "$SKILLS_SRC"/*/; do
  skill="$(basename "$skill_dir")"
  scan_unsynced "$skill_dir" "$SKILLS_DST/$skill" "skills/$skill" dir
done
for hook in "$HOOKS_SRC"/*.py; do
  [[ -e "$hook" ]] || continue
  base="$(basename "$hook")"
  scan_unsynced "$hook" "$HOOKS_DST/$base" "hooks/$base" file
done
if [[ -d "$AGENTS_SRC" ]]; then
  shopt -s nullglob
  for agent in "$AGENTS_SRC"/*.md; do
    base="$(basename "$agent")"
    scan_unsynced "$agent" "$AGENTS_DST/$base" "agents/$base" file
  done
  shopt -u nullglob
fi
scan_unsynced "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST" "CLAUDE.md" file
if [[ -d "$CURSOR_RULES_SRC" ]]; then
  shopt -s nullglob
  for rule in "$CURSOR_RULES_SRC"/*.mdc; do
    base="$(basename "$rule")"
    scan_unsynced "$rule" "$CURSOR_RULES_DST/$base" "cursor: $base" file
  done
  shopt -u nullglob
fi

if [[ ${#UNSYNCED[@]} -gt 0 ]]; then
  log "warning: the following look like unsynced edits made directly under ~/.claude/:"
  for note in "${UNSYNCED[@]}"; do
    log "  - $note"
  done
  log ""
  log "  → run: make sync-from-system   (or make install-system --force)"
  log ""
  if ! $FORCE && ! $DRY_RUN; then
    log "Aborting install (use --force to overwrite unsynced system edits)."
    exit 1
  fi
fi

if ! $DRY_RUN; then
  mkdir -p "$SKILLS_DST" "$HOOKS_DST" "$AGENTS_DST" "$HOME/.local/bin" "$HOME/.claude/logs" "$CONFIG_DST_DIR" "$CURSOR_RULES_DST"
  mkdir -p "$(dirname "$MEMORY_DST")"
fi

log "1. Skills (symlinks)"
for skill_dir in "$SKILLS_SRC"/*/; do
  skill="$(basename "$skill_dir")"
  link_item "${skill_dir%/}" "$SKILLS_DST/$skill" "$skill" dir
done

log ""
log "2. Retired skills (remove symlink, if ours)"
for retired in "${RETIRED_SKILLS[@]}"; do
  remove_retired "$SKILLS_DST/$retired" "$retired"
done

log ""
log "3. Hooks (*.py, symlinks)"
for hook in "$HOOKS_SRC"/*.py; do
  [[ -e "$hook" ]] || continue
  link_item "$hook" "$HOOKS_DST/$(basename "$hook")" "hook: $(basename "$hook")" file
done

log ""
log "3b. Subagents (*.md, symlinks)"
if [[ -d "$AGENTS_SRC" ]]; then
  shopt -s nullglob
  agents=("$AGENTS_SRC"/*.md)
  shopt -u nullglob
  if [[ ${#agents[@]} -eq 0 ]]; then
    log "skip (no .md files): ai/claude/agents/"
  else
    for agent in "${agents[@]}"; do
      link_item "$agent" "$AGENTS_DST/$(basename "$agent")" "agent: $(basename "$agent")" file
    done
  fi
else
  log "skip (missing source): ai/claude/agents/"
fi

log ""
log "4. CLAUDE.md (symlink, formatting overlay)"
link_item "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST" "CLAUDE.md" file

log ""
log "5. Cursor rules (*.mdc, symlinks)"
if [[ -d "$CURSOR_RULES_SRC" ]]; then
  shopt -s nullglob
  rules=("$CURSOR_RULES_SRC"/*.mdc)
  shopt -u nullglob
  if [[ ${#rules[@]} -eq 0 ]]; then
    log "skip (no .mdc files): ai/cursor/rules/"
  else
    for rule in "${rules[@]}"; do
      base="$(basename "$rule")"
      link_item "$rule" "$CURSOR_RULES_DST/$base" "cursor: $base" file
    done
  fi
else
  log "skip (missing source): ai/cursor/rules/"
fi

log ""
log "5b. Retired Cursor rules"
for retired in "${RETIRED_CURSOR_RULES[@]}"; do
  remove_retired "$CURSOR_RULES_DST/$retired" "$retired"
done

log ""
log "6. Memory (copy to project path — not symlinked, see principles/deployment.md)"
install_dir "$MEMORY_SRC" "$MEMORY_DST" "memory"

log ""
log "7. clog (symlink)"
if [[ -f "$CLOG_SRC" ]]; then
  $DRY_RUN || chmod +x "$CLOG_SRC"
  link_item "$CLOG_SRC" "$CLOG_DST" "clog" file
fi

log ""
log "7b. cli-filter (symlink)"
if [[ -f "$CLI_FILTER_SRC" ]]; then
  $DRY_RUN || chmod +x "$CLI_FILTER_SRC"
  link_item "$CLI_FILTER_SRC" "$CLI_FILTER_DST" "cli-filter" file
fi

log ""
log "8. Private config (create-if-missing, never symlinked)"
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
log "9. Config validation"
if [[ -f "$CONFIG_DST" && -f "$CONFIG_TEMPLATE" ]]; then
  export CONFIG_DST CONFIG_TEMPLATE
  python3 << 'PY'
import json, os, sys
from pathlib import Path

template = json.loads(Path(os.environ["CONFIG_TEMPLATE"]).read_text())
try:
    local = json.loads(Path(os.environ["CONFIG_DST"]).read_text())
except Exception as e:
    print(f"  ⚠ could not parse local.json: {e}")
    sys.exit(0)

def flatten(obj, prefix=""):
    out = {}
    for k, v in obj.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flatten(v, key))
        else:
            out[key] = v
    return out

t_flat = flatten(template)
l_flat = flatten(local)

PLACEHOLDER_PATTERNS = ("YOUR_", "<your-", "ACME", "acme", "PROJ-12345", "collection://YOUR")
SKIP_KEYS = {"$schema", "comment"}

unfilled = []
for key, t_val in t_flat.items():
    if any(s in key for s in SKIP_KEYS):
        continue
    l_val = l_flat.get(key)
    if l_val is None:
        continue
    is_empty = l_val == "" or l_val == 0 or l_val == []
    is_placeholder = isinstance(l_val, str) and any(p in l_val for p in PLACEHOLDER_PATTERNS)
    is_unchanged = l_val == t_val and (is_empty or is_placeholder)
    if is_empty or is_placeholder or is_unchanged:
        unfilled.append(key)

if unfilled:
    print(f"  ⚠  {len(unfilled)} key(s) appear unfilled in local.json:")
    for k in unfilled:
        print(f"     {k}")
    print("  → Edit ~/.config/ai-skills/local.json or sync from Notion")
else:
    configured = sum(1 for k, v in l_flat.items()
                     if v not in ("", 0, []) and not any(p in str(v) for p in PLACEHOLDER_PATTERNS))
    print(f"  ✓ local.json looks configured ({configured} non-empty keys)")
PY
else
  log "  skip (local.json not present yet)"
fi

log ""
if $DRY_RUN; then
  log "Dry run complete."
else
  count="$(find "$SKILLS_DST" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')"
  write_system_manifest
  log "Done. $count skills linked in $SKILLS_DST"
  log "Reload Claude Code (new conversation) to pick up new/removed items."
fi
log ""
