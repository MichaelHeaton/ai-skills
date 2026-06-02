#!/usr/bin/env bash
# Detect where to route a new issue based on git remote.
# Outputs one of:
#   jira-work
#   linear:<project>
#   github-current:<owner/repo>
#   gitlab-current:<namespace/repo>
#
# Repo → Linear project (optional precision):
#   ~/.config/ai-skills/repo-routing.json  — private cache exported from Notion (see docs/guides/repo-routing-cache.md)
#   Built-in name/prefix heuristics when cache is missing or repo not listed
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
  local ticket_system="Linear"
  local linear_project

  if [[ -f "$ROUTING_FILE" ]]; then
    ticket_system=$(jq -r --arg repo "$repo_slug" '
      .repos[$repo].ticket_system // empty
    ' "$ROUTING_FILE")
    linear_project=$(jq -r --arg repo "$repo_slug" '
      .repos[$repo].linear_project // empty
    ' "$ROUTING_FILE")
    if [[ -z "$ticket_system" ]]; then
      ticket_system="Linear"
    fi
  fi

  if [[ -z "${linear_project:-}" ]]; then
    linear_project=$(heuristic_linear_project "$repo_slug")
  fi

  if [[ "${ISSUE_ROUTE:-}" == "github" ]] || [[ "$ticket_system" == "GitHub" ]]; then
    echo "github-current:${repo_slug}"
  elif [[ "$ticket_system" == "Jira" ]]; then
    echo "jira-work"
  else
    echo "linear:${linear_project}"
  fi
}

default_no_remote_project() {
  if [[ -f "$ROUTING_FILE" ]]; then
    jq -r '.defaults.no_remote.linear_project // "Personal"' "$ROUTING_FILE"
  else
    echo "Personal"
  fi
}

if [[ -z "$remote" ]]; then
  echo "linear:$(default_no_remote_project)"
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
  echo "linear:$(default_no_remote_project)"
fi
