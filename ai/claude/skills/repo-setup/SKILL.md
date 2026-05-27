---

name: repo-setup
description: Verify and set up project repositories on the current workstation. Checks that required repos are cloned, configures the correct git identity and gh CLI account per repo via direnv, and installs dependencies. Use when starting work on a new workstation, when a skill fails because a repo isn't found, when commits are going out under the wrong git identity, or when the wrong gh account is active. Triggers on: "set up this workstation", "clone the repos I need", "repo not found", "missing ces-documentation", "set up my projects", "new machine setup", "workstation setup", "wrong git account", "fix git identity".
compatibility: Requires git, direnv (brew install direnv), and an internet connection to clone missing repos.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


<!-- pii-exempt: intentional account configuration — contains real emails and usernames as a setup reference for this workstation -->

# Repo Setup

Check that the repos needed for AI-assisted workflows are present and correctly configured on the current workstation. This covers three concerns: repos exist, git identity is right, and the `gh` CLI uses the right account.

---

## Accounts

Three git identities are in use:

| Account | Email | SSH host | gh user | Used for |
|---|---|---|---|---|
| Adobe | `ult35127@adobe.com` | `github.com` | `ult35127_adobe` | Adobe/CES repos, `git@github.com:ult35127_adobe/...` |
| Personal GitHub | `michael@heatons.me` | `github.com-personal` | `MichaelHeaton` | Personal repos, `git@github.com-personal:MichaelHeaton/...` |

The global `~/.gitconfig` defaults to the Adobe identity. Personal repos override this via `git config --local` (set by the account setup script) and via `~/.gitconfig includeIf` blocks (set during new workstation setup).

---

## Known project repos

| Repo | Expected path | Skills that need it | Clone URL |
|---|---|---|---|
| ces-documentation | `~/Projects/adobe/ces-documentation` | `doc-coauthor` | `git@github.com:ult35127_adobe/ces-documentation.git` |
| claude-skills | `~/Projects/personal/claude-skills` | all skills | `git@github.com-personal:MichaelHeaton/claude-skills.git` |
| memex | `~/Projects/personal/memex` | `issue-create`, `issue-list`, `issue-get`, `issue-update` | `git@github.com-personal:MichaelHeaton/memex.git` |

---

## Workflow

### 1. Check what's present

```bash
for path in ~/Projects/adobe/ces-documentation ~/Projects/personal/claude-skills ~/Projects/personal/memex; do
  [ -d "$path/.git" ] && echo "✓ $path" || echo "✗ $path (missing)"
done
```

Report what's present and what's missing before taking any action.

### 2. Clone missing repos

Confirm with the user before cloning — they may be on a machine without network access or want a different path.

```bash
git clone <clone-url> <expected-path>
```

If an Adobe clone fails: check VPN connectivity and SSH key (`ssh -T github.com`).
If a personal clone fails: check SSH key (`ssh -T github.com-personal`).

### 3. Configure git account per repo

Run the account setup script for each repo (existing or newly cloned):

```bash
bash ~/.claude/skills/repo-setup/scripts/setup-account.sh <repo-path>
```

The script:
- Detects the account from the remote URL
- Sets `git config --local user.name` and `user.email`
- Writes `.envrc` with `export GH_TOKEN=$(gh auth token --user <gh-user>)` so the `gh` CLI uses the right account automatically when you're in that directory
- Adds `.envrc` to `.gitignore`
- Runs `direnv allow`

### 4. Set up ~/.gitconfig includeIf (new workstation only)

This is a safety net for repos not configured via this script. Check first:

```bash
grep -A2 'includeIf' ~/.gitconfig 2>/dev/null || echo "(not configured)"
```

If missing, add these blocks to `~/.gitconfig`:

```ini
[includeIf "gitdir:~/Projects/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/Projects/personal-gitlab/"]
    path = ~/.gitconfig-personal
```

And create `~/.gitconfig-personal`:

```ini
[user]
    name = Michael Heaton
    email = michael@heatons.me
```

This ensures any repo under `~/Projects/personal/` or `~/Projects/personal-gitlab/` uses the personal identity even if the setup script hasn't been run yet.

### 5. Environment files (.env)

For repos that require a `.env` (separate from `.envrc`):

```bash
ls -la <path>/.env 2>/dev/null || echo "missing"
cat <path>/.env.example 2>/dev/null
```

If `.env` is missing, show `.env.example` and ask the user to fill in the values. Do not guess credential values.

### 6. Dependencies

```bash
# Python
cd <path> && pip install -r requirements.txt 2>/dev/null

# Node
cd <path> && npm install 2>/dev/null
```

Report failures — don't silently skip them.

### 7. Makefile presence (personal repos)

Each personal repo should have a `Makefile` with at least a default entry point. Check:

```bash
ls <path>/Makefile 2>/dev/null || echo "missing"
```

If missing, create a minimal one. For repos with an install script (`scripts/install.sh`):

```makefile
.PHONY: install

install:
	@bash scripts/install.sh
```

For provisioning/Ansible repos (e.g., `workstation-devops`), a `make apply` target is the convention.

If an existing `managed_repos` entry in `workstation-devops/group_vars/all.yml` uses `install_cmd: bash install.sh`, update it to `install_cmd: make install`.

### 8. Skill symlinks (claude-skills only)

If `claude-skills` was just cloned, run the install from the repo root:

```bash
make install  # in <clone-path>/
```

### 9. Seed standard GitHub labels (personal repos only)

For each personal GitHub repo (`claude-skills`, `memex`, and any new ones), seed the standard label taxonomy. Skip `ces-documentation` — it's an Adobe repo. This is idempotent, safe to re-run.

```bash
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh <owner/repo>
# e.g.:
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh ${GITHUB_PERSONAL_USER}/claude-skills
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh ${GITHUB_PERSONAL_USER}/memex
```

`claude-skills` gets `type/*` + `priority/*` labels. All other personal repos get `domain/*` + `priority/*`.

---

## After setup

Report a summary:
- Which repos are configured and which accounts are active
- Any `.envrc` files created and whether `direnv allow` succeeded
- Any manual steps still needed (`.env` values, VPN, SSH keys)
- Remind the user to reload Claude Code to pick up newly symlinked skills
