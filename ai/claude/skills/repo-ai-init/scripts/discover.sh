#!/usr/bin/env bash
# Produces a structured discovery report for a git repository.
# Usage: bash scripts/discover.sh [repo-path]
# Defaults to current directory if no path given.

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

section() { echo ""; echo "=== $1 ==="; }

section "REPO"
echo "Path: $(pwd)"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

section "GIT HISTORY (last 20 commits)"
git log --oneline -20 2>/dev/null || echo "(no git history)"

section "COMMIT PATTERNS (top recurring subjects, last 100)"
git log --format='%s' -100 2>/dev/null \
  | sed 's/[0-9]\{4,\}//g' \
  | sort | uniq -c | sort -rn | head -20 \
  || echo "(none)"

section "FILE STRUCTURE (depth 3, excluding build artifacts)"
find . -maxdepth 3 -type f \
  | grep -v -E '(\./\.git/|node_modules|__pycache__|\.venv|\.env$|/dist/|/build/|\.DS_Store|\.pyc$)' \
  | sort

section "TECH STACK"
for f in package.json go.mod Cargo.toml requirements.txt Pipfile pyproject.toml pom.xml build.gradle Gemfile; do
  if [[ -f "$f" ]]; then
    echo ""
    echo "FOUND: $f"
    head -20 "$f"
  fi
done

section "AI CONTEXT FILES"
# Root AI context file: report whichever of AGENTS.md (plural, community
# standard default) / AGENT.md (singular, legacy) already exists in this
# repo. If neither exists yet, report the new default (AGENTS.md) as missing.
if [[ -f "AGENTS.md" ]]; then
  lines=$(wc -l < "AGENTS.md" | tr -d ' ')
  echo "FOUND:   AGENTS.md  ($lines lines)"
elif [[ -f "AGENT.md" ]]; then
  lines=$(wc -l < "AGENT.md" | tr -d ' ')
  echo "FOUND:   AGENT.md  ($lines lines)"
else
  echo "MISSING: AGENTS.md"
fi
for f in CLAUDE.md .cursorrules .aider.conf.yml .github/copilot-instructions.md; do
  if [[ -f "$f" ]]; then
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "FOUND:   $f  ($lines lines)"
  else
    echo "MISSING: $f"
  fi
done

section "BUILD / TEST COMMANDS"
if [[ -f Makefile ]]; then
  echo "--- Makefile targets ---"
  grep -E '^[a-zA-Z][a-zA-Z0-9_-]*:' Makefile | head -20 || true
fi
if [[ -f package.json ]]; then
  echo "--- package.json scripts ---"
  python3 -c "
import sys, json
try:
    d = json.load(open('package.json'))
    for k,v in d.get('scripts',{}).items():
        print(f'  {k}: {v}')
except Exception as e:
    print(f'  (parse error: {e})')
" 2>/dev/null || true
fi
if [[ -f Makefile ]] || [[ -f package.json ]]; then true; else
  echo "(no Makefile or package.json found)"
fi

section "README (first 80 lines)"
if [[ -f README.md ]]; then
  head -80 README.md
elif [[ -f README.rst ]]; then
  head -80 README.rst
else
  echo "(no README found)"
fi

section "EXISTING DOCS / SPECS"
find . -maxdepth 3 -type f \( -name '*.md' -o -name '*.rst' -o -name '*.txt' \) \
  | grep -v -E '(\./\.git/|node_modules|CHANGELOG|LICENSE|NOTICE)' \
  | sort \
  | head -30
