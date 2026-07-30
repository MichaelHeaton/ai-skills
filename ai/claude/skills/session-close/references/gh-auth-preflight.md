---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# GH auth pre-flight (before Step 2)

Before processing any GitHub.com repo — personal or work/org — verify the active `gh` account matches that repo's owner. The "Repository not found" account-mismatch failure mode is identical regardless of whose repo it is; don't read this as personal-repo-only because of how the variable below happens to be named. Run this once now — don't wait for a push failure.

First, ensure `GITHUB_PERSONAL_USER` is set — it must be exported before any `gh` call. If it's not in the environment, read it from local config:

```bash
if [[ -z "${GITHUB_PERSONAL_USER:-}" ]]; then
  GITHUB_PERSONAL_USER=$(jq -r '.accounts.personal.github_user // empty' \
    ~/.config/ai-skills/local.json 2>/dev/null)
fi
export GITHUB_PERSONAL_USER
```

If still empty after this, stop and ask the user to set `GITHUB_PERSONAL_USER` in their shell profile or `~/.config/ai-skills/local.json` — all personal GitHub operations depend on it.

Then verify the active account:

```bash
gh auth status 2>&1 | grep "Logged in to github.com account"
```

If the active account is not `${GITHUB_PERSONAL_USER}`, capture it so it can be restored at the end of this run (Step 10), then switch:

```bash
ORIGINAL_GH_ACCOUNT=$(gh auth status 2>&1 | grep "Active account: true" -B1 | grep "Logged in to github.com account" | awk '{print $(NF-1)}')
gh auth switch --hostname github.com --user "${GITHUB_PERSONAL_USER}"
```

**Always pass `--hostname github.com`.** With more than one host authenticated in `gh` (e.g. github.com plus an internal GHE/GitLab host), `gh auth switch --user <name>` fails outright with "unable to determine which account to switch to, please specify --hostname and --user" — the hostname flag isn't optional in that environment.

If the active account already matches `${GITHUB_PERSONAL_USER}`, skip this capture — there's nothing to restore later.
