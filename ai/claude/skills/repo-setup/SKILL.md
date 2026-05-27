---

name: repo-setup
description: Verify and set up project repositories on the current workstation. Checks that required repos are cloned, configures the correct git identity and gh CLI account per repo via direnv, and installs dependencies. Use when starting work on a new workstation, when a skill fails because a repo isn't found, when commits are going out under the wrong git identity, or when the wrong gh account is active. Triggers on: "set up this workstation", "clone the repos I need", "repo not found", "missing work docs repo", "set up my projects", "new machine setup", "workstation setup", "wrong git account", "fix git identity".
compatibility: Requires git, direnv (brew install direnv), and an internet connection to clone missing repos.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# Repo Setup

Check that the repos needed for AI-assisted workflows are present and correctly configured. Covers: repos exist, git identity is correct, and `gh` uses the right account.

## Step 0 — Load local config

Read `~/.config/claude-skills/local.json` and source `~/.config/claude-skills/accounts.shell` when present ([references/local-config.md](../../../references/local-config.md)).

Use `accounts.personal`, `accounts.work`, `accounts.client_contract` (or your own keys) in JSON — each with `remote_match` for `setup-account.sh`.

The setup script prefers **`local.json`** (jq) and falls back to **`accounts.shell`** exports.

---

## Accounts (pattern)

| Account | JSON key | Shell exports (optional) |
|---------|----------|---------------------------|
| Personal GitHub | `accounts.personal` | `GITHUB_PERSONAL_USER`, `SKILLS_PERSONAL_*` |
| Employer | `accounts.work` | `SKILLS_ADOBE_*` / `SKILLS_WORK_*`, `SKILLS_WORK_ORGS` |
| Client / GitLab | `accounts.client_contract` | `SKILLS_UV_*` or your own exports |

Global `~/.gitconfig` often defaults to work; personal repos override via `git config --local` and `includeIf` (see §4).

---

## Known project repos (examples)

Adjust paths and clone URLs in **your** `local.json` — do not commit them here.

| Repo | Typical path | Skills |
|------|--------------|--------|
| Work docs | `repos.work_docs` | `doc-coauthor`, `vault-support` |
| claude-skills | `~/Projects/personal/claude-skills` | all |
| memex | `~/Projects/personal/memex` | `issue-*`, `memex-*` |

---

## Workflow

### 1. Check what's present

```bash
# Example — substitute paths from local.yaml
for path in "${SKILLS_WORK_DOCS_REPO}" ~/Projects/personal/claude-skills ~/Projects/personal/memex; do
  [ -d "$path/.git" ] && echo "✓ $path" || echo "✗ $path (missing)"
done
```

### 2. Clone missing repos

Confirm with the user before cloning.

### 3. Configure git account per repo

```bash
bash ~/.claude/skills/repo-setup/scripts/setup-account.sh <repo-path>
```

The script detects account from remote URL, sets local git identity, writes `.envrc` for `GH_TOKEN`, and runs `direnv allow`.

### 4. Set up ~/.gitconfig includeIf (new workstation only)

See previous `includeIf` blocks for `~/Projects/personal/` → `~/.gitconfig-personal` with name/email from `local.yaml` → `personal.*`.

### 5. Environment files (.env)

Show `.env.example` if `.env` is missing; never guess secrets.

### 6–7. Dependencies and Makefile

As before — install deps, ensure `Makefile` exists where expected.

### 8. Skill symlinks (claude-skills)

```bash
cd ~/Projects/personal/claude-skills && make install
```

Creates `~/.config/claude-skills/local.json` from template if missing.

### 9. Seed standard GitHub labels (personal repos only)

```bash
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh "${GITHUB_PERSONAL_USER}/claude-skills"
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh "${GITHUB_PERSONAL_USER}/memex"
```

---

## After setup

Report configured repos, `.envrc` status, and any manual steps (`.env`, VPN, SSH). Remind user to reload AI sessions after `make install`.
