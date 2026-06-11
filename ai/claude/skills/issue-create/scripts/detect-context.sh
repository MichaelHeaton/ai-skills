#!/usr/bin/env bash
# Detect where to route a new issue based on git remote.
# Outputs one of:
#   jira-work
#   github-current:<owner/repo>
#   memex
#   linear:<project>        (only when routing file explicitly sets ticket_system=Linear)
#   gitlab-current:<namespace/repo>
#
# Override via routing file:
#   ~/.config/ai-skills/repo-routing.json  — set ticket_system per repo (GitHub/Linear/Jira/Notion)
#
# Configure work GitHub orgs (comma-separated):
#   export SKILLS_WORK_ORGS=org1,org2
#
# Configure personal GitHub orgs that should route to Linear (comma-separated):
#   export PERSONAL_GITHUB_ORGS=org1,org2
#   (also readable from ~/.config/ai-skills/local.json: personal_github_orgs array)
#
# Force GitHub for player/tester reports or PR-linked issues:
#   export ISSUE_ROUTE=github

set -euo pipefail

ROUTING_FILE="${REPO_ROUTING_FILE:-${HOME}/.config/ai-skills/repo-routing.json}"
LOCAL_JSON="${HOME}/.config/ai-skills/local.json"

remote=$(git remote get-url origin 2>/dev/null || true)
IFS=',' read -ra work_orgs <<< "${SKILLS_WORK_ORGS:-}"

# Read personal_github_orgs from env or local.json
personal_orgs_env="${PERSONAL_GITHUB_ORGS:-}"
if [[ -z "$personal_orgs_env" ]] && [[ -f "$LOCAL_JSON" ]]; then
  personal_orgs_env=$(jq -r '(.personal_github_orgs // []) | join(",")' "$LOCAL_JSON" 2>/dev/null || true)
fi
IFS=',' read -ra personal_orgs <<< "$personal_orgs_env"

heuristic_linear_project() {
  local repo_slug="$1"
  local name="${repo_slug#*/}"
  case "$name" in
    workstation-devops) echo "Workstation DevOps" ;;
    ai-skills) echo "AI Skills" ;;
    memex|memex-suite|workspaces|nexus) echo "Personal" ;;
    minecraft-modpack-*) echo "Minecraft Modpacks" ;;
    homelab-*|ansible-role-*|tf-module-*|platform-bootstrap) echo "Homelab" ;;
    *) echo "Personal" ;;
  esac
}

lookup_repo() {
  local repo_slug="$1"
  local ticket_system=""
  local linear_project=""

  if [[ -f "$ROUTING_FILE" ]]; then
    ticket_system=$(jq -r --arg repo "$repo_slug" '
      .repos[$repo].ticket_system // empty
    ' "$ROUTING_FILE")
    linear_project=$(jq -r --arg repo "$repo_slug" '
      .repos[$repo].linear_project // empty
    ' "$ROUTING_FILE")
  fi

  if [[ "${ISSUE_ROUTE:-}" == "github" ]] || [[ "$ticket_system" == "GitHub" ]] || [[ -z "$ticket_system" ]]; then
    echo "github-current:${repo_slug}"
  elif [[ "$ticket_system" == "Jira" ]]; then
    echo "jira-work"
  elif [[ "$ticket_system" == "Linear" ]]; then
    if [[ -z "${linear_project:-}" ]]; then
      linear_project=$(heuristic_linear_project "$repo_slug")
    fi
    echo "linear:${linear_project}"
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

for porg in "${personal_orgs[@]}"; do
  porg="${porg// /}"
  [[ -z "$porg" ]] && continue
  if [[ "$remote" == *"github.com:$porg/"* ]] || [[ "$remote" == *"github.com/$porg/"* ]] || [[ "$remote" == *"github.com-personal:$porg/"* ]]; then
    repo=$(echo "$remote" | sed -E 's|.*github\.com[:/]||;s|.*github\.com-personal:||;s|\.git$||')
    lp=$(heuristic_linear_project "$repo")
    echo "linear:${lp}"
    exit 0
  fi
done

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
