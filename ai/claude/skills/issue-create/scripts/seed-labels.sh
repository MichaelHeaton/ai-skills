#!/usr/bin/env bash
# Seed standard labels for a personal GitHub repo.
# Usage: seed-labels.sh <owner/repo>
# Idempotent — safe to run on repos that already have some or all labels.

set -euo pipefail

REPO="${1:?Usage: seed-labels.sh <owner/repo>}"

export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER:?GITHUB_PERSONAL_USER not set}")

seed() {
  local name="$1" desc="$2" color="$3"
  gh label create "$name" --repo "$REPO" --description "$desc" --color "$color" 2>/dev/null || true
}

seed "priority/high"   "Urgent, time-sensitive, blocking other work" "dc2626"
seed "priority/medium" "Important but flexible timeline"             "d97706"
seed "priority/low"    "Nice-to-have, no specific deadline"          "6b7280"
seed "type/brain-dump" "Quick capture, needs triage"                "6b7280"
seed "triage/needs-grooming" "Brain dump not yet converted to a proper issue" "f59e0b"

# Skills repo uses type/*; other personal repos use domain/* (see categories/tags.yaml)
if echo "$REPO" | grep -qiE 'ai-skills|ai-skills'; then
  seed "type/new-skill"   "Proposing or building a new skill" "f97316"
  seed "type/enhancement" "Improving an existing skill"       "a2eeef"
  seed "type/bug"         "Skill producing wrong output"      "d73a4a"
  seed "type/review"      "Periodic review or tune-up"        "7057ff"
else
  seed "domain/work-primary"    "Primary employer work without a Jira ticket" "e8433a"
  seed "domain/client-contract" "Client / contract work"                      "7c3aed"
  seed "domain/homelab"         "Homelab infra and self-hosted services"      "0284c7"
  seed "domain/learning"        "Certs, courses, skills"                      "16a34a"
  seed "domain/personal"        "Family, finances, general home life"        "db2777"
  seed "domain/mtb"             "Coaching, team, race logistics"              "ea580c"
  seed "domain/iot"             "IoT devices and automations"                 "0891b2"
fi

echo "✓ Labels seeded for $REPO"
