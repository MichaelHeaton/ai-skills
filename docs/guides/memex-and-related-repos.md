---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Memex and related repositories

## Memex is a project name, not a generic term

**[Memex](https://github.com/MichaelHeaton/memex)** is the maintainer’s personal **second brain** — a private markdown vault (tasks, meetings, wiki, CRM). It is **not** a product everyone is expected to run or name their vault.

In this workspace:

| Where you see “Memex” | Meaning |
|----------------------|---------|
| `comms_write.memex_repo_path` in `local.template.json` | **Example default** pointing at the author’s clone path (`~/Projects/personal/memex`) |
| Skill names like `memex-dump`, `memex-decide` | **Legacy skill IDs** in claude-skills / future `ai/claude/skills/` — kept for compatibility |
| Memex repo paths in docs | The author’s vault layout (`GitHub/Issues/`, `Wiki/`, `ai/claude/skills/comms-write-context/`, …) |

If you fork or reuse **ai-skills**, use your own PKM repo and set:

- `routing.personal_kb_github` → `your-user/your-vault-repo`
- `comms_write.examples_root` or your repo path — do not assume a project called Memex

## How the repos fit together

| Repo | Role |
|------|------|
| **ai-skills** (this repo) | Public principles, config templates, skills (after import), install scripts |
| **[claude-skills](https://github.com/MichaelHeaton/claude-skills)** | Legacy runtime for skills until `make install-system` ships here |
| **[Memex](https://github.com/MichaelHeaton/memex)** | Private knowledge vault; employer-specific comms-write examples under `ai/claude/skills/comms-write-context/` |
| **[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops)** | Ansible bootstrap: clones repos, applies dotfiles, runs skill install on the author’s Macs |

## Install on the author’s machines

**[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops)** is the supported way to install and refresh tooling on those workstations:

- Clones `personal/ai-skills`, `personal/claude-skills`, and `personal/memex` (see `group_vars/all.yml` → `managed_repos_common`)
- Today: runs **`make install`** in **claude-skills** to deploy skills to `~/.claude/skills/`
- Copies config **templates** only — filled `~/.config/ai-skills/local.json` stays on the machine ([local-config.md](local-config.md))
- Target: **`make install-system`** in **ai-skills** after PR-F import (replaces claude-skills as deploy source)

Manual install (any machine):

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git ~/Projects/personal/ai-skills
cp config/local.template.json ~/.config/ai-skills/local.json   # then edit
cd ~/Projects/personal/claude-skills && make install             # until install-system exists
```

Workstation playbook: `make apply` from `~/Projects/personal/workstation-devops`.
