#!/usr/bin/env bash
# Configure git identity and direnv GH_TOKEN from ~/.config/ai-skills/local.json
# Usage: setup-account.sh [repo-path]

set -euo pipefail

REPO="${1:-.}"
LOCAL_JSON="${AI_SKILLS_LOCAL:-$HOME/.config/ai-skills/local.json}"

cd "$REPO"

if [[ ! -f "$LOCAL_JSON" ]]; then
  echo "error: missing $LOCAL_JSON — copy from ai-skills config/local.template.json" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "error: jq required" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  echo "error: no origin remote" >&2
  exit 1
fi

echo "Remote: $REMOTE_URL"

match_account() {
  local key="$1"
  local patterns
  patterns=$(jq -r --arg k "$key" '.accounts[$k].remote_match[]? // empty' "$LOCAL_JSON" 2>/dev/null) || true
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    if [[ "$REMOTE_URL" == *"$pat"* ]]; then
      echo "$key"
      return 0
    fi
  done <<< "$patterns"
  return 1
}

ACCOUNT_KEY=""
for key in personal work client_contract; do
  if match_account "$key"; then
    ACCOUNT_KEY="$key"
    break
  fi
done

if [[ -z "$ACCOUNT_KEY" ]]; then
  ACCOUNT_KEY="work"
  echo "warning: no remote_match hit — defaulting to accounts.work"
fi

GIT_NAME=$(jq -r --arg k "$ACCOUNT_KEY" '.accounts[$k].git_name // empty' "$LOCAL_JSON")
GIT_EMAIL=$(jq -r --arg k "$ACCOUNT_KEY" '.accounts[$k].git_email // empty' "$LOCAL_JSON")
GH_USER=$(jq -r --arg k "$ACCOUNT_KEY" '.accounts[$k].github_user // empty' "$LOCAL_JSON")
LABEL=$(jq -r --arg k "$ACCOUNT_KEY" '.accounts[$k].label // $k' "$LOCAL_JSON")

if [[ -z "$GIT_EMAIL" || -z "$GH_USER" ]]; then
  echo "error: fill accounts.$ACCOUNT_KEY in $LOCAL_JSON" >&2
  exit 1
fi

echo "Detected account: $LABEL ($ACCOUNT_KEY)"
echo ""

git config --local user.name  "$GIT_NAME"
git config --local user.email "$GIT_EMAIL"
echo "✓ git identity: $GIT_NAME <$GIT_EMAIL>"

ENVRC=".envrc"
ENVRC_CONTENT="export GH_TOKEN=\$(gh auth token --user $GH_USER 2>/dev/null)"

if [[ -f "$ENVRC" ]] && grep -qF "$ENVRC_CONTENT" "$ENVRC"; then
  echo "✓ .envrc already configured"
else
  echo "$ENVRC_CONTENT" > "$ENVRC"
  echo "✓ .envrc written"
fi

if [[ -f .gitignore ]]; then
  grep -qx ".envrc" .gitignore 2>/dev/null || echo ".envrc" >> .gitignore
else
  echo ".envrc" > .gitignore
fi

if command -v direnv &>/dev/null; then
  direnv allow . 2>/dev/null && echo "✓ direnv allow"
else
  echo "⚠️  install direnv: brew install direnv"
fi

echo ""
echo "Done."
