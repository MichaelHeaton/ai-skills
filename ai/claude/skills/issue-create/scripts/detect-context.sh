#!/usr/bin/env bash
# Detect where to route a new issue based on the current git remote.
# Outputs one of:
#   jira-cesss
#   github-current:<owner/repo>
#   memex
#
# Configure work GitHub orgs (comma-separated):
#   export SKILLS_WORK_ORGS=org1,org2
# Remotes matching any listed org route to jira-cesss.

remote=$(git remote get-url origin 2>/dev/null || true)
IFS=',' read -ra work_orgs <<< "${SKILLS_WORK_ORGS:-}"

if [[ -z "$remote" ]]; then
  echo "memex"
  exit 0
fi

for org in "${work_orgs[@]}"; do
  org="${org// /}"  # trim whitespace
  [[ -z "$org" ]] && continue
  if [[ "$remote" == *"github.com:$org/"* ]] || [[ "$remote" == *"github.com/$org/"* ]]; then
    echo "jira-cesss"
    exit 0
  fi
done

if [[ "$remote" == *"github.com-personal:"* ]]; then
  repo=$(echo "$remote" | sed 's|.*github\.com-personal:||;s|\.git$||')
  echo "github-current:$repo"
elif [[ "$remote" == *"github.com:"* ]]; then
  repo=$(echo "$remote" | sed 's|.*github\.com:||;s|\.git$||')
  echo "github-current:$repo"
elif [[ "$remote" == *"gitlab.com"* ]]; then
  repo=$(echo "$remote" | sed 's|.*gitlab\.com[:/]||;s|\.git$||')
  echo "gitlab-current:$repo"
else
  echo "memex"
fi
