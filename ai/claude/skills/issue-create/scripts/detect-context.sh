#!/usr/bin/env bash
# Detect where to route a new issue based on git remote.
# Outputs one of:
#   jira-work
#   github-current:<owner/repo>
#   memex
#   gitlab-current:<namespace/repo>
#
# Override via routing file:
#   ~/.config/ai-skills/repo-routing.json  — set ticket_system per repo (GitHub/Jira/Notion)
#
# Configure work GitHub orgs (comma-separated):
#   export SKILLS_WORK_ORGS=org1,org2
#
# Force GitHub for player/tester reports or PR-linked issues:
#   export ISSUE_ROUTE=github

set -euo pipefail

ROUTING_FILE="${REPO_ROUTING_FILE:-${HOME}/.config/ai-skills/repo-routing.json}"

remote=$(git remote get-url origin 2>/dev/null || true)
IFS=',' read -ra work_orgs <<< "${SKILLS_WORK_ORGS:-}"

lookup_repo() {
  local repo_slug="$1"
  local ticket_system=""

  if [[ -f "$ROUTING_FILE" ]]; then
    ticket_system=$(jq -r --arg repo "$repo_slug" '
      .repos[$repo].ticket_system // empty
    ' "$ROUTING_FILE")
  fi

  if [[ "$ticket_system" == "Jira" ]]; then
    echo "jira-work"
  else
    echo "github-current:${repo_slug}"
  fi
}

if [[ -z "$remote" ]]; then
  echo "memex"
  exit 0
fi

for org in "${work_orgs[@]}"; do
  org="${org// /}"
  [[ -z "$org" ]] && continue
  if [[ "$remote" == *"github.com:$org/"* ]] || [[ "$remote" == *"github.com/$org/"* ]]; then
    echo "jira-work"
    exit 0
  fi
done

if [[ "${ISSUE_ROUTE:-}" == "github" ]]; then
  repo=$(echo "$remote" | sed -E 's|.*github\.com[:/]||;s|.*github\.com-personal:||;s|\.git$||')
  echo "github-current:${repo}"
  exit 0
fi

if [[ "$remote" == *"github.com-personal:"* ]]; then
  repo=$(echo "$remote" | sed 's|.*github\.com-personal:||;s|\.git$||')
  lookup_repo "$repo"
elif [[ "$remote" == *"github.com:"* ]] || [[ "$remote" == *"github.com/"* ]]; then
  repo=$(echo "$remote" | sed -E 's|.*github\.com[:/]||;s|\.git$||')
  lookup_repo "$repo"
elif [[ "$remote" == *"gitlab.com"* ]]; then
  repo=$(echo "$remote" | sed 's|.*gitlab\.com[:/]||;s|\.git$||')
  echo "gitlab-current:$repo"
else
  echo "memex"
fi
