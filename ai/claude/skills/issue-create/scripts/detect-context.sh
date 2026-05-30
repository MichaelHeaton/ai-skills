#!/usr/bin/env bash
# Detect where to route a new issue based on git remote and repo-routing.json.
# Outputs one of:
#   jira-work
#   linear:<project>
#   github-current:<owner/repo>
#   gitlab-current:<namespace/repo>
#
# Configure work GitHub orgs (comma-separated):
#   export SKILLS_WORK_ORGS=org1,org2
#
# Force GitHub for player/tester reports or PR-linked issues:
#   export ISSUE_ROUTE=github

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTING_FILE="${REPO_ROUTING_FILE:-${SCRIPT_DIR}/../references/repo-routing.json}"

remote=$(git remote get-url origin 2>/dev/null || true)
IFS=',' read -ra work_orgs <<< "${SKILLS_WORK_ORGS:-}"

lookup_repo() {
  local repo_slug="$1"
  if [[ ! -f "$ROUTING_FILE" ]]; then
    echo "linear:Personal"
    return
  fi

  local ticket_system linear_project
  ticket_system=$(jq -r --arg repo "$repo_slug" '
    .repos[$repo].ticket_system //
    (if ($repo | test("^[^/]+/minecraft-modpack-")) then "Linear"
     elif ($repo | test("^[^/]+/homelab-")) then "Linear"
     elif ($repo | test("^[^/]+/ansible-role-")) then "Linear"
     elif ($repo | test("^[^/]+/tf-module-")) then "Linear"
     else .defaults.unknown_personal_repo.ticket_system end)
  ' "$ROUTING_FILE")

  linear_project=$(jq -r --arg repo "$repo_slug" '
    .repos[$repo].linear_project //
    (if ($repo | test("^[^/]+/minecraft-modpack-")) then "Minecraft Modpacks"
     elif ($repo | test("^[^/]+/homelab-")) then "Homelab"
     elif ($repo | test("^[^/]+/ansible-role-")) then "Homelab"
     elif ($repo | test("^[^/]+/tf-module-")) then "Homelab"
     else .defaults.unknown_personal_repo.linear_project end)
  ' "$ROUTING_FILE")

  if [[ "${ISSUE_ROUTE:-}" == "github" ]] || [[ "$ticket_system" == "GitHub" ]]; then
    echo "github-current:${repo_slug}"
  elif [[ "$ticket_system" == "Jira" ]]; then
    echo "jira-work"
  else
    echo "linear:${linear_project}"
  fi
}

if [[ -z "$remote" ]]; then
  if [[ -f "$ROUTING_FILE" ]]; then
    project=$(jq -r '.defaults.no_remote.linear_project' "$ROUTING_FILE")
    echo "linear:${project}"
  else
    echo "linear:Personal"
  fi
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
  if [[ -f "$ROUTING_FILE" ]]; then
    project=$(jq -r '.defaults.no_remote.linear_project' "$ROUTING_FILE")
    echo "linear:${project}"
  else
    echo "linear:Personal"
  fi
fi
