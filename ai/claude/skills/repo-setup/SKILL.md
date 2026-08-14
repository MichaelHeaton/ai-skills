---
version: 1.1.1
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: repo-setup
description: Verify and set up project repositories on the current workstation. Covers repo cloning, git identity, gh CLI config via direnv, dependencies, and repo infrastructure conventions (Makefile, standard make targets, entry points). Triggers on set up workstation, clone repos, repo not found, missing work docs repo, new machine setup, wrong git account, fix git identity, add a Makefile, standard make targets, repo doesn't have a Makefile, repos should follow a standard structure, standardize repo structure, repo infrastructure.
compatibility: Local machine only — direnv and workstation-level git identity setup have no cloud/web-session equivalent. Requires git, direnv (brew install direnv), jq, and ~/.config/ai-skills/local.json filled from config/local.template.json.
---

# Repo setup

Check that repos needed for AI-assisted workflows exist and are configured. Covers: repos present, correct git identity, correct `gh` account (via direnv).

**Before starting:** read `~/.config/ai-skills/local.json` — especially `accounts.*`, `repos.*`, `routing.personal_kb_github`, `comms_write.memex_repo_path`.

---

## Typical repos (from local.json)

| Key | Purpose | Example skills |
| --- | --- | --- |
| `repos.work_docs` | Work documentation / wiki mirror | `doc-coauthor`, `vault-support` |
| `repos.work_skills` | Customer-facing work skills | `vault-support` |
| Clone of **this** repo (`ai-skills`) | Skill source | all skills |
| `comms_write.memex_repo_path` or path for `routing.personal_kb_github` | Personal KB | `issue-*`, `memex-dump` |

Paths and clone URLs are **private** — do not hardcode them in tickets or public commits.

---

## Workflow

### 1. Check what's present

For each path in `repos.*` and your ai-skills / personal KB paths:

```bash
[ -d "$path/.git" ] && echo "✓ $path" || echo "✗ $path (missing)"
```

Report before cloning.

### 2. Clone missing repos

Confirm with the user. Use SSH URLs from their git hosting (work vs personal host aliases from `accounts.*.ssh_host`).

If a **work** clone fails: VPN and `ssh -T` for the work host.

If a **personal** clone fails: `ssh -T` for the personal host alias (e.g. `github.com-personal`).

### 3. Configure git account per repo

```bash
bash ~/.claude/skills/repo-setup/scripts/setup-account.sh <repo-path>
```

The script matches the remote URL to `accounts.*.remote_match` in local.json and sets local git identity + `.envrc` for `GH_TOKEN`.

### 4. includeIf safety net (new workstation)

Optional `~/.gitconfig` blocks for `~/Projects/personal/` → `~/.gitconfig-personal` with name/email from `accounts.personal` in local.json. See your workstation bootstrap docs.

### 5. Environment files

For repos with `.env.example`, ensure `.env` exists locally — never commit it. Do not guess secrets.

### 6. Dependencies

Run each repo's documented install (`pip install -r requirements.txt`, `npm install`, `make install`, etc.). Report failures.

### 7. Makefile

Personal repos should expose `make install` or document their entry point. Provisioning repos may use `make apply` (e.g. workstation-devops).

### 8. Deploy skills (ai-skills)

After cloning ai-skills:

```bash
cd <ai-skills-path> && make install-system
```

Until `install-system` exists, follow [docs/ROADMAP.md](../../../docs/ROADMAP.md) for interim deploy.

### 9. Seed GitHub labels (personal repos)

```bash
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh <owner/repo>
```

Run for `YOUR_USER/ai-skills` and `routing.personal_kb_github`. Skip work-only doc repos.

---

## After setup

- Which repos are configured and which account each uses
- Whether direnv is active (`direnv status` in a repo directory)
- Reload Claude Code after skill deploy (new conversation)
