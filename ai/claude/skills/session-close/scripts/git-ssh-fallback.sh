#!/usr/bin/env bash
# Wraps git remote operations for repos using SSH (GitHub or GitLab).
# On failure, probes port 22 and auto-switches the remote from SSH to HTTPS, then retries.
# Non-SSH remotes are passed through unchanged.
# Usage: git-ssh-fallback.sh <repo-path> <git-subcommand> [args...]

REPO="${1:?Usage: git-ssh-fallback.sh <repo-path> <git-subcommand> [args...]}"
shift

get_remote_url() {
  git -C "$REPO" remote get-url origin 2>/dev/null
}

is_ssh_url() {
  local url="$1"
  [[ "$url" =~ ^git@(github|gitlab)\. ]] || [[ "$url" =~ ^ssh://git@(github|gitlab)\. ]]
}

extract_ssh_host() {
  local url="$1"
  if [[ "$url" =~ ^git@([^:]+): ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$url" =~ ^ssh://git@([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

ssh_url_to_https() {
  local url="$1"
  # git@github.com:owner/repo.git   ->  https://github.com/owner/repo.git
  # git@gitlab.com:group/repo.git   ->  https://gitlab.com/group/repo.git
  if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  elif [[ "$url" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
}

port22_blocked() {
  local host="$1"
  local probe
  probe=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
    "git@${host}" 2>&1 || true)
  echo "$probe" | grep -qE \
    "port 22:? (Connection refused|Operation timed out|Network unreachable|No route to host)|port 22 timed out|kex_exchange_identification|Connection closed by remote host|banner exchange"
}

ORIGINAL_URL=$(get_remote_url)

# Not an SSH remote — pass through with no wrapping
if ! is_ssh_url "$ORIGINAL_URL"; then
  exec git -C "$REPO" "$@"
fi

# Use a short ConnectTimeout so port-22 failures surface quickly
SSH_BASE="${GIT_SSH_COMMAND:-ssh}"
GIT_SSH_COMMAND="${SSH_BASE} -o ConnectTimeout=15" git -C "$REPO" "$@"
GIT_EXIT=$?

[[ $GIT_EXIT -eq 0 ]] && exit 0

# Git failed — probe port 22 to confirm the cause before switching
SSH_HOST=$(extract_ssh_host "$ORIGINAL_URL")
if [[ -z "$SSH_HOST" ]] || ! port22_blocked "$SSH_HOST"; then
  exit $GIT_EXIT  # Not a port-22 issue; preserve original exit code
fi

# Port 22 confirmed blocked — auto-switch remote to HTTPS and retry
HTTPS_URL=$(ssh_url_to_https "$ORIGINAL_URL")
if [[ -z "$HTTPS_URL" ]]; then
  printf '✗ Cannot derive HTTPS URL from: %s\n' "$ORIGINAL_URL" >&2
  exit $GIT_EXIT
fi

printf '\n⚠️  SSH port 22 blocked on %s — switching remote to HTTPS:\n' "$SSH_HOST" >&2
printf '   %s\n   → %s\n' "$ORIGINAL_URL" "$HTTPS_URL" >&2
git -C "$REPO" remote set-url origin "$HTTPS_URL"

git -C "$REPO" "$@"
RETRY_EXIT=$?

if [[ $RETRY_EXIT -eq 0 ]]; then
  printf '✓ Succeeded via HTTPS (remote permanently updated)\n' >&2
else
  printf '✗ HTTPS fallback also failed — remote remains at HTTPS URL\n' >&2
fi

exit $RETRY_EXIT
