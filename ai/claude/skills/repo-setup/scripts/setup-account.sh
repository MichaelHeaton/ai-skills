#!/usr/bin/env bash
# Detects the git account for a repo based on its remote URL and configures:
#   - git config --local user.email / user.name
#   - .envrc with the right GH_TOKEN (for gh CLI)
#   - direnv allow
#
# Usage: bash scripts/setup-account.sh [repo-path]
# Defaults to current directory.

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

# ── Account definitions ────────────────────────────────────────────────────────

declare -A ADOBE=(
  [name]="Michael Heaton"
  [email]="ult35127@adobe.com"
  [gh_user]="ult35127_adobe"
  [label]="Adobe (ult35127_adobe)"
)

declare -A PERSONAL=(
  [name]="Michael Heaton"
  [email]="michael@heatons.me"
  [gh_user]="MichaelHeaton"
  [label]="Personal (MichaelHeaton)"
)

# ── Detect account from remote URL ─────────────────────────────────────────────

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [[ -z "$REMOTE_URL" ]]; then
  echo "⚠️  No 'origin' remote found. Set one with: git remote add origin <url>"
  exit 1
fi

echo "Remote: $REMOTE_URL"

if [[ "$REMOTE_URL" == *"github.com-personal"* ]] || \
   [[ "$REMOTE_URL" == *"github.com/MichaelHeaton"* ]] || \
   [[ "$REMOTE_URL" == *"github.com:MichaelHeaton"* ]]; then
  ACCOUNT_LABEL="${PERSONAL[label]}"
  GIT_NAME="${PERSONAL[name]}"
  GIT_EMAIL="${PERSONAL[email]}"
  GH_USER="${PERSONAL[gh_user]}"

else
  # Default: Adobe (covers git@github.com:ult35127_adobe/..., git.corp.adobe.com, etc.)
  ACCOUNT_LABEL="${ADOBE[label]}"
  GIT_NAME="${ADOBE[name]}"
  GIT_EMAIL="${ADOBE[email]}"
  GH_USER="${ADOBE[gh_user]}"
fi

echo "Detected account: $ACCOUNT_LABEL"
echo ""

# ── Git local identity ─────────────────────────────────────────────────────────

CURRENT_EMAIL=$(git config --local user.email 2>/dev/null || echo "")
CURRENT_NAME=$(git config --local user.name 2>/dev/null || echo "")

if [[ "$CURRENT_EMAIL" == "$GIT_EMAIL" ]] && [[ "$CURRENT_NAME" == "$GIT_NAME" ]]; then
  echo "✓ git identity already set ($GIT_EMAIL)"
else
  git config --local user.name  "$GIT_NAME"
  git config --local user.email "$GIT_EMAIL"
  echo "✓ git identity set: $GIT_NAME <$GIT_EMAIL>"
fi

# ── .envrc (direnv) ────────────────────────────────────────────────────────────

ENVRC=".envrc"

ENVRC_CONTENT="export GH_TOKEN=\$(gh auth token --user $GH_USER 2>/dev/null)"

if [[ -f "$ENVRC" ]]; then
  if grep -qF "$ENVRC_CONTENT" "$ENVRC"; then
    echo "✓ .envrc already configured for $ACCOUNT_LABEL"
  else
    echo "⚠️  .envrc exists but doesn't match expected content."
    echo "   Current:"
    cat "$ENVRC"
    echo "   Expected line: $ENVRC_CONTENT"
    echo "   Edit .envrc manually if needed."
  fi
else
  echo "$ENVRC_CONTENT" > "$ENVRC"
  echo "✓ .envrc created"
fi

# Ensure .envrc is gitignored
GITIGNORE=".gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qx ".envrc" "$GITIGNORE" 2>/dev/null; then
    echo ".envrc" >> "$GITIGNORE"
    echo "✓ .envrc added to .gitignore"
  else
    echo "✓ .envrc already in .gitignore"
  fi
else
  echo ".envrc" > "$GITIGNORE"
  echo "✓ .gitignore created with .envrc"
fi

# ── direnv allow ──────────────────────────────────────────────────────────────

if command -v direnv &>/dev/null; then
  direnv allow . 2>/dev/null && echo "✓ direnv allow"
else
  echo "⚠️  direnv not found — install with: brew install direnv"
  echo "   Then run: direnv allow $(pwd)"
fi

echo ""
echo "Done. Account configured: $ACCOUNT_LABEL"
