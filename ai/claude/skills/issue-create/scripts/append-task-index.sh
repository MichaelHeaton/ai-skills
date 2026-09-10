#!/usr/bin/env bash
# Append one record to the Memex task index with a worktree safety check.
#
# Usage:
#   append-task-index.sh --system <github|gitlab|jira> \
#     --id <NUMBER|KEY> --url <url> --title <title> --domain <domain> \
#     [--repo <owner/repo>] [--instance <str>] [--project <name>] \
#     [--status <open|closed>] [--created <YYYY-MM-DD>]

set -euo pipefail

MEMEX_DIR="${HOME}/Projects/personal/memex"
INDEX_FILE="${MEMEX_DIR}/Raw/_task-index.jsonl"

if [[ ! -d "${MEMEX_DIR}/Raw" ]]; then
  echo "⚠️ memex vault not found locally — skipping task-index append" >&2
  exit 0
fi

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

# Guard against bundling a concurrent session's in-progress edits into this
# commit in a shared, non-worktree checkout: stage only the index file, then
# check for any other already-staged content before committing.
git -C "${MEMEX_DIR}" add "${INDEX_FILE}"

INDEX_REL="${INDEX_FILE#${MEMEX_DIR}/}"
OTHER_STAGED=$(git -C "${MEMEX_DIR}" diff --cached --name-only | grep -v -F -x "${INDEX_REL}" || true)
if [[ -n "${OTHER_STAGED}" ]]; then
  echo "⚠️  Other staged content found in ${MEMEX_DIR} — aborting commit to avoid bundling it in:" >&2
  echo "${OTHER_STAGED}" | sed 's/^/   /' >&2
  echo "   #${ID} is appended to the index file but not committed — commit it manually once the other staged content is resolved." >&2
  exit 0
fi

git -C "${MEMEX_DIR}" commit -q -m "chore(task-index): add #${ID} (${SYSTEM})"
echo "✓ Committed task-index entry for #${ID}"
