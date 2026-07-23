#!/usr/bin/env bash
# Non-destructive drift report: symlink presence, git ahead/behind, Desktop/
# claude.ai upload drift, push-skills target drift. Never writes anything.
# `--json` emits a machine-readable summary (used by the SessionStart hook).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-paths.sh
. "$SCRIPT_DIR/lib/deploy-paths.sh"

JSON=false
for arg in "$@"; do
  [[ "$arg" == "--json" ]] && JSON=true
done

# ── (a) link presence — reuse install-system.sh's own dry-run output ───────
INSTALL_OUT="$(bash "$SCRIPT_DIR/install-system.sh" --dry-run 2>&1 || true)"
PENDING=$(grep -c '  → ' <<<"$INSTALL_OUT" || true)
UNSYNCED_WARN=$(grep -c '^warning:' <<<"$INSTALL_OUT" || true)

# ── (b) local vs origin ahead/behind (bounded so a dead network can't hang) ─
TIMEOUT_CMD=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_CMD="timeout 8"

GIT_CHECKED=false
GIT_AHEAD=0
GIT_BEHIND=0
if $TIMEOUT_CMD git -C "$REPO_DIR" fetch --quiet origin 2>/dev/null; then
  if counts="$(git -C "$REPO_DIR" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null)"; then
    GIT_AHEAD="$(awk '{print $1}' <<<"$counts")"
    GIT_BEHIND="$(awk '{print $2}' <<<"$counts")"
    GIT_CHECKED=true
  fi
fi

# ── (c) Desktop/claude.ai upload drift ──────────────────────────────────────
DESKTOP_STATE="$REPO_DIR/.deploy/desktop-upload-state.json"
STALE_SKILLS="$(SKILLS_SRC="$SKILLS_SRC" DESKTOP_STATE="$DESKTOP_STATE" python3 << 'PY'
import json, os
from pathlib import Path

state_path = Path(os.environ["DESKTOP_STATE"])
skills_src = Path(os.environ["SKILLS_SRC"])
stale = []
if state_path.is_file():
    try:
        state = json.loads(state_path.read_text()).get("skills", {})
    except Exception:
        state = {}
    for name, rec in state.items():
        skill_md = skills_src / name / "SKILL.md"
        current = "0.0.0"
        if skill_md.is_file():
            for line in skill_md.read_text().splitlines():
                if line.startswith("version:"):
                    current = line.split(":", 1)[1].strip()
                    break
        if current != rec.get("version"):
            stale.append(name)
print(json.dumps(stale))
PY
)"

# ── (d) push-skills target drift ────────────────────────────────────────────
PUSH_TARGETS_CFG="$HOME/.config/ai-skills/push-targets.json"
PUSH_REPORT="$(REPO_DIR="$REPO_DIR" PUSH_TARGETS_CFG="$PUSH_TARGETS_CFG" python3 << 'PY'
import json, os, subprocess
from pathlib import Path

cfg_path = Path(os.environ["PUSH_TARGETS_CFG"])
repo_dir = Path(os.environ["REPO_DIR"])
behind = []
unreachable = []

if cfg_path.is_file():
    try:
        targets = json.loads(cfg_path.read_text()).get("targets", [])
    except Exception:
        targets = []
    for t in targets:
        path = Path(os.path.expanduser(t.get("path", "")))
        bundle = t.get("bundle", "universal")
        if not (path / ".git").is_dir():
            unreachable.append({"path": str(path), "bundle": bundle})
            continue
        bundle_file = repo_dir / "skill-sets" / f"{bundle}.txt"
        if not bundle_file.is_file():
            unreachable.append({"path": str(path), "bundle": bundle})
            continue
        skills = [
            line.split("#", 1)[0].strip()
            for line in bundle_file.read_text().splitlines()
            if line.split("#", 1)[0].strip()
        ]
        drifted = False
        for skill in skills:
            src = repo_dir / "ai" / "claude" / "skills" / skill
            dst = path / ".claude" / "skills" / skill
            if not src.is_dir():
                continue
            result = subprocess.run(
                ["rsync", "-ani", "--delete", f"{src}/", f"{dst}/"],
                capture_output=True, text=True,
            )
            if result.stdout.strip():
                drifted = True
                break
        if drifted:
            behind.append({"path": str(path), "bundle": bundle})

print(json.dumps({"behind": behind, "unreachable": unreachable}))
PY
)"

# ── assemble + print ─────────────────────────────────────────────────────────
if $JSON; then
  PENDING="$PENDING" UNSYNCED_WARN="$UNSYNCED_WARN" GIT_CHECKED="$GIT_CHECKED" \
  GIT_AHEAD="$GIT_AHEAD" GIT_BEHIND="$GIT_BEHIND" STALE_SKILLS="$STALE_SKILLS" \
  PUSH_REPORT="$PUSH_REPORT" python3 << 'PY'
import json, os

print(json.dumps({
    "repo_vs_system": {
        "pending_links": int(os.environ["PENDING"]),
        "unsynced_warnings": int(os.environ["UNSYNCED_WARN"]),
    },
    "git": {
        "ahead": int(os.environ["GIT_AHEAD"]),
        "behind": int(os.environ["GIT_BEHIND"]),
        "checked": os.environ["GIT_CHECKED"] == "true",
    },
    "desktop_upload": {"stale_skills": json.loads(os.environ["STALE_SKILLS"])},
    "push_targets": json.loads(os.environ["PUSH_REPORT"]),
}))
PY
else
  echo ""
  echo "ai-skills status"
  echo ""
  echo "1. Repo -> ~/.claude/ links"
  if [[ "$PENDING" -eq 0 && "$UNSYNCED_WARN" -eq 0 ]]; then
    echo "   ok — everything linked"
  else
    [[ "$PENDING" -gt 0 ]] && echo "   $PENDING item(s) pending — run: make install-system"
    [[ "$UNSYNCED_WARN" -gt 0 ]] && echo "   unsynced edits found — run: make sync-from-system"
  fi
  echo ""
  echo "2. Local vs origin"
  if $GIT_CHECKED; then
    echo "   ahead=$GIT_AHEAD behind=$GIT_BEHIND"
    [[ "$GIT_BEHIND" -gt 0 ]] && echo "   → git pull"
  else
    echo "   git check skipped (offline, no upstream, or timeout)"
  fi
  echo ""
  echo "3. Desktop/claude.ai upload drift"
  STALE_SKILLS="$STALE_SKILLS" python3 << 'PY'
import json, os
stale = json.loads(os.environ["STALE_SKILLS"])
if not stale:
    print("   ok — no tracked skills changed since last upload")
else:
    print(f"   {len(stale)} skill(s) changed since last upload:")
    for s in stale:
        print(f"     - {s}")
    print("   → make package-skill SKILL=<name>, upload manually, then make mark-uploaded SKILL=<name>")
PY
  echo ""
  echo "4. push-skills targets"
  PUSH_REPORT="$PUSH_REPORT" python3 << 'PY'
import json, os
report = json.loads(os.environ["PUSH_REPORT"])
behind = report.get("behind", [])
unreachable = report.get("unreachable", [])
if not behind and not unreachable:
    print("   no targets configured or all up to date (see config/push-targets.template.json)")
for t in behind:
    print(f"   behind: {t['path']} ({t['bundle']}) — run: make push-skills-all")
for t in unreachable:
    print(f"   unreachable: {t['path']} ({t['bundle']})")
PY
  echo ""
fi
