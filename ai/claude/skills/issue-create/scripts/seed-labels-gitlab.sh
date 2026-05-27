#!/usr/bin/env bash
# Seed standard labels for a GitLab repo.
# Usage: seed-labels-gitlab.sh <namespace/repo>
# Idempotent — safe to run on repos that already have some or all labels.

set -euo pipefail

REPO="${1:?Usage: seed-labels-gitlab.sh <namespace/repo>}"

seed() {
  local name="$1" color="$2"
  glab label create --name "$name" --color "$color" --repo "$REPO" 2>/dev/null || true
}

# Priority labels
seed "priority/high"   "#dc2626"
seed "priority/medium" "#d97706"
seed "priority/low"    "#6b7280"

# Cross-repo type labels
seed "type/brain-dump"       "#6b7280"

# Triage state — remove when ticket has been properly groomed
seed "triage/needs-grooming" "#f59e0b"

echo "✓ Labels seeded for $REPO"
