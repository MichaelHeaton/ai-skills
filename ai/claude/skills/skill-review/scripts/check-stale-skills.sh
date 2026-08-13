#!/usr/bin/env bash
# Flag skills whose SKILL.md `last_updated` frontmatter is older than the
# threshold — low-frequency skills (e.g. security-review, comms-write) can
# otherwise go untouched for months without ever coming up for review,
# since session-audit mode only looks at skills that actually fired.
#
# Usage: check-stale-skills.sh [skills-dir] [threshold-days]
# Output: STALE:<days-old>:<skill-name>:<last_updated>
# Exits 0 always — this is advisory, not a hard gate.

SKILLS_DIR="${1:-$HOME/.claude/skills}"
THRESHOLD_DAYS="${2:-90}"

[[ -d "$SKILLS_DIR" ]] || { echo "usage: check-stale-skills.sh [skills-dir] [threshold-days]" >&2; exit 0; }

NOW_EPOCH=$(date +%s)

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  name="$(basename "$(dirname "$skill_md")")"
  last_updated=$(grep -m1 '^last_updated:' "$skill_md" | sed 's/^last_updated:[[:space:]]*//')
  [[ -z "$last_updated" ]] && continue

  last_epoch=$(date -d "$last_updated" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_updated" +%s 2>/dev/null)
  [[ -z "$last_epoch" ]] && continue

  days_old=$(( (NOW_EPOCH - last_epoch) / 86400 ))
  if (( days_old >= THRESHOLD_DAYS )); then
    echo "STALE:${days_old}:${name}:${last_updated}"
  fi
done
