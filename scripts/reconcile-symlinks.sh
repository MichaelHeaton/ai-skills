#!/usr/bin/env bash
# Reconcile symlinks after a commit/merge — creates links for newly added
# items and removes links for retired items. Never touches content (nothing
# to sync: symlinked items can't diverge from the repo). Never aborts: only
# ever creates a brand-new link or removes a link this repo owns, so there's
# no staleness case to guard against. Safe to run unattended on every
# post-commit/post-merge. Does not touch memory/ or local.json (manual only).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"
# shellcheck source=lib/link-items.sh
. "$SCRIPT_DIR/lib/link-items.sh"

DRY_RUN=false
FORCE=false

mkdir -p "$SKILLS_DST" "$HOOKS_DST" "$AGENTS_DST" "$HOME/.local/bin" "$CONFIG_DST_DIR" "$CURSOR_RULES_DST" 2>/dev/null || true

for skill_dir in "$SKILLS_SRC"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill="$(basename "$skill_dir")"
  link_item "${skill_dir%/}" "$SKILLS_DST/$skill" "$skill" dir
done

for retired in "${RETIRED_SKILLS[@]}"; do
  remove_retired "$SKILLS_DST/$retired" "$retired"
done

for hook in "$HOOKS_SRC"/*.py; do
  [[ -e "$hook" ]] || continue
  link_item "$hook" "$HOOKS_DST/$(basename "$hook")" "hook: $(basename "$hook")" file
done

if [[ -d "$AGENTS_SRC" ]]; then
  shopt -s nullglob
  for agent in "$AGENTS_SRC"/*.md; do
    link_item "$agent" "$AGENTS_DST/$(basename "$agent")" "agent: $(basename "$agent")" file
  done
  shopt -u nullglob
fi

link_item "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST" "CLAUDE.md" file

if [[ -d "$CURSOR_RULES_SRC" ]]; then
  shopt -s nullglob
  for rule in "$CURSOR_RULES_SRC"/*.mdc; do
    base="$(basename "$rule")"
    link_item "$rule" "$CURSOR_RULES_DST/$base" "cursor: $base" file
  done
  shopt -u nullglob
fi

for retired in "${RETIRED_CURSOR_RULES[@]}"; do
  remove_retired "$CURSOR_RULES_DST/$retired" "$retired"
done

if [[ -f "$CLOG_SRC" ]]; then
  chmod +x "$CLOG_SRC" 2>/dev/null || true
  link_item "$CLOG_SRC" "$CLOG_DST" "clog" file
fi

if [[ -f "$CLI_FILTER_SRC" ]]; then
  chmod +x "$CLI_FILTER_SRC" 2>/dev/null || true
  link_item "$CLI_FILTER_SRC" "$CLI_FILTER_DST" "cli-filter" file
fi

exit 0
