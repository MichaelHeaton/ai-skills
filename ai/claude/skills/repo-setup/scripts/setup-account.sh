#!/usr/bin/env bash
# Configure git identity + .envrc for the current repo from local.json or accounts.shell.
set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

CONFIG_DIR="${HOME}/.config/claude-skills"
LOCAL_JSON="${CONFIG_DIR}/local.json"
ACCOUNTS_SHELL="${CONFIG_DIR}/accounts.shell"

if [[ -f "$ACCOUNTS_SHELL" ]]; then
  # shellcheck source=/dev/null
  source "$ACCOUNTS_SHELL"
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  echo "⚠️  No 'origin' remote found."
  exit 1
fi
echo "Remote: $REMOTE_URL"

# ── Prefer local.json account matching ─────────────────────────────────────────

ACCOUNT_ID=""
GIT_NAME=""
GIT_EMAIL=""
GH_USER=""

if [[ -f "$LOCAL_JSON" ]] && command -v jq &>/dev/null; then
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    while IFS= read -r fragment; do
      [[ -z "$fragment" ]] && continue
      if [[ "$REMOTE_URL" == *"$fragment"* ]]; then
        ACCOUNT_ID="$id"
        break 2
      fi
    done < <(jq -r --arg id "$id" '.accounts[$id].remote_match[]? // empty' "$LOCAL_JSON")
  done < <(jq -r '.accounts | keys[]' "$LOCAL_JSON")

  if [[ -n "$ACCOUNT_ID" ]]; then
    GIT_NAME=$(jq -r --arg id "$ACCOUNT_ID" '.accounts[$id].git_name // ""' "$LOCAL_JSON")
    GIT_EMAIL=$(jq -r --arg id "$ACCOUNT_ID" '.accounts[$id].git_email // ""' "$LOCAL_JSON")
    GH_USER=$(jq -r --arg id "$ACCOUNT_ID" '.accounts[$id].github_user // ""' "$LOCAL_JSON")
    LABEL=$(jq -r --arg id "$ACCOUNT_ID" '.accounts[$id].label // $id' "$LOCAL_JSON")
    echo "Matched account: $LABEL (local.json → $ACCOUNT_ID)"
  fi
fi

# ── Fallback: legacy env vars / heuristics ─────────────────────────────────────

if [[ -z "$GIT_EMAIL" ]]; then
  personal_host="${SKILLS_PERSONAL_GH_HOST:-github.com-personal}"
  if [[ "$REMOTE_URL" == *"${personal_host}"* ]] || \
     [[ -n "${GITHUB_PERSONAL_USER:-}" && "$REMOTE_URL" == *"${GITHUB_PERSONAL_USER}"* ]]; then
    GIT_NAME="${SKILLS_PERSONAL_GIT_NAME:-Git User}"
    GIT_EMAIL="${SKILLS_PERSONAL_EMAIL:-}"
    GH_USER="${GITHUB_PERSONAL_USER:-}"
    LABEL="Personal (${GH_USER})"
  elif [[ "$REMOTE_URL" == *"gitlab.com"* ]]; then
    GIT_NAME="${SKILLS_UV_GIT_NAME:-${SKILLS_PERSONAL_GIT_NAME:-Git User}}"
    GIT_EMAIL="${SKILLS_UV_GIT_EMAIL:-${SKILLS_PERSONAL_EMAIL:-}}"
    GH_USER=""
    LABEL="GitLab"
  else
    GIT_NAME="${SKILLS_ADOBE_GIT_NAME:-${SKILLS_WORK_GIT_NAME:-Git User}}"
    GIT_EMAIL="${SKILLS_ADOBE_GIT_EMAIL:-${SKILLS_WORK_GIT_EMAIL:-}}"
    GH_USER="${SKILLS_ADOBE_GH_USER:-${SKILLS_WORK_GH_USER:-}}"
    LABEL="Work (${GH_USER:-work})"
  fi
  echo "Matched account: $LABEL (heuristic)"
fi

if [[ -z "$GIT_EMAIL" ]]; then
  echo "⚠️  Configure ~/.config/claude-skills/local.json or accounts.shell"
  exit 1
fi

# ── Git local identity ─────────────────────────────────────────────────────────

git config --local user.name  "$GIT_NAME"
git config --local user.email "$GIT_EMAIL"
echo "✓ git identity: $GIT_NAME <$GIT_EMAIL>"

# ── .envrc ─────────────────────────────────────────────────────────────────────

if [[ -n "$GH_USER" ]]; then
  ENVRC_CONTENT="export GH_TOKEN=\$(gh auth token --user $GH_USER 2>/dev/null)"
else
  ENVRC_CONTENT="# No GH_TOKEN for this remote"
fi

if [[ -f .envrc ]] && grep -qF "$ENVRC_CONTENT" .envrc; then
  echo "✓ .envrc already configured"
else
  echo "$ENVRC_CONTENT" > .envrc
  echo "✓ .envrc written"
fi

if [[ -f .gitignore ]]; then
  grep -qx ".envrc" .gitignore 2>/dev/null || echo ".envrc" >> .gitignore
else
  echo ".envrc" > .gitignore
fi

if command -v direnv &>/dev/null; then
  direnv allow . 2>/dev/null && echo "✓ direnv allow"
fi

echo "Done."
