#!/usr/bin/env bash
# Append one record to the Memex task index with a worktree safety check.
#
# Usage:
#   append-task-index.sh --system <linear|github|gitlab|jira> \
#     --id <NUMBER|KEY> --url <url> --title <title> --domain <domain> \
#     [--repo <owner/repo>] [--instance <str>] [--project <name>] \
#     [--status <open|closed>] [--created <YYYY-MM-DD>]

set -euo pipefail

MEMEX_DIR="${HOME}/Projects/personal/memex"
INDEX_FILE="${MEMEX_DIR}/Raw/_task-index.jsonl"

SYSTEM="" REPO="null" INSTANCE="null" ID="" URL="" TITLE="" DOMAIN=""
PROJECT="null" STATUS="open" CREATED="$(date +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system)   SYSTEM="$2";   shift 2 ;;
    --repo)     REPO="$2";     shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    --id)       ID="$2";       shift 2 ;;
    --url)      URL="$2";      shift 2 ;;
    --title)    TITLE="$2";    shift 2 ;;
    --domain)   DOMAIN="$2";   shift 2 ;;
    --project)  PROJECT="$2";  shift 2 ;;
    --status)   STATUS="$2";   shift 2 ;;
    --created)  CREATED="$2";  shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

for var in SYSTEM ID URL TITLE DOMAIN; do
  if [[ -z "${!var}" ]]; then
    echo "Error: --${var,,} is required" >&2; exit 1
  fi
done

BRANCH=$(git -C "${MEMEX_DIR}" branch --show-current 2>/dev/null || echo "unknown")
if [[ "${BRANCH}" != "main" ]]; then
  echo "⚠️  Memex is on branch '${BRANCH}', not main — entry will land on this branch." >&2
  echo "   Note it for session-close." >&2
fi

jq -cn \
  --arg  system   "$SYSTEM"   \
  --arg  repo     "$REPO"     \
  --arg  instance "$INSTANCE" \
  --arg  id       "$ID"       \
  --arg  url      "$URL"      \
  --arg  title    "$TITLE"    \
  --arg  domain   "$DOMAIN"   \
  --arg  project  "$PROJECT"  \
  --arg  status   "$STATUS"   \
  --arg  created  "$CREATED"  \
  '{v:1,
    system:   $system,
    repo:     (if $repo     == "null" then null else $repo     end),
    instance: (if $instance == "null" then null else $instance end),
    id:       $id,
    url:      $url,
    title:    $title,
    domain:   $domain,
    project:  (if $project  == "null" then null else $project  end),
    status:   $status,
    created:  $created,
    vault_ref: null}' \
  >> "${INDEX_FILE}"

echo "✓ Appended #${ID} to task index"
