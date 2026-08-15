---
version: 2.0.0
principles_version: 1.0.0
last_updated: 2026-08-15
updated_by: human
---

# Issue routing rules

Run `scripts/detect-context.sh` from the current working directory. All `issue-*` skills and `memex-dump` use this logic.

**Notion SoT:** `System → Repositories` (`notion.repositories_data_source` in local.json) holds `Ticket System` per repo. Agents with Notion MCP use it when routing is ambiguous.

**Shell cache (optional, private):** `~/.config/ai-skills/repo-routing.json` — one-way export from Notion for `detect-context.sh`. Not committed to git. See `docs/guides/repo-routing-cache.md`. Without the cache, the script defaults to GitHub Issues — in the current repo when a git remote exists, or Memex (`MichaelHeaton/memex`) when there's no remote.

Read `routing.*` from `~/.config/ai-skills/local.json`.

## Routing targets

| Output | Meaning | Where issues go |
| --- | --- | --- |
| `jira-work` | Remote matches `routing.work_github_orgs` or `SKILLS_WORK_ORGS` (Adobe) | Jira — `jira.project_key` in local.json |
| `github-current:<owner/repo>` | Personal work in a repo with a known git remote (default) | GitHub Issues in that repo |
| `memex` | No git remote / cross-cutting capture (default) | GitHub Issues in `MichaelHeaton/memex` |
| `gitlab-current:<namespace/repo>` | GitLab remote | GitLab Issues in that repo |

Two systems only: **GitHub for personal work**, **Jira for Adobe work**. Nothing else.

### GitHub routing (personal repos)

| Situation | Route |
| --- | --- |
| Default capture in any personal repo | `github-current:<repo>` — create the GitHub Issue directly in-repo |
| Minecraft modpack dev or player/tester/playtest report | `github-current:<modpack-repo>` — same route either way |
| No git remote / brain dump / cross-cutting capture | `memex` — GitHub Issues in `MichaelHeaton/memex` |

## Domain tags (task index)

Domain tagging is independent of which system a ticket lives in — it's a label/task-index field applied to GitHub issues so cross-cutting work stays sortable by area.

| Domain tag | Use for |
| --- | --- |
| `work-primary` | Adobe work-adjacent notes without a Jira ticket (`memex`, not Jira — it's a personal note about work, not an official ticket) |
| `client-contract` | Contractor ops, hiring, reporting (UV Cyber) |
| `homelab` | Homelab / infra, dotfiles, dev machine setup (Workstation DevOps) |
| `learning` | `ai-skills`, agent rules, MCP |
| `personal` | Life admin, misc, Minecraft modpack work |
| `mtb` | Coaching, NICA, trails |

**Default skill repo:** `ai-skills`.

## Jira (work context)

Read `~/.config/ai-skills/local.json`:

- **Project key**: `jira.project_key`
- **Default type**: `jira.default_issue_type` (usually `Story`)
- **Never create Epics** unless your org allows it — see `jira.epic_owners_note`
- **Epic linking**: `jira.epic_link_field` when the user names an epic
- **Updates go in comments**, not body edits

Work org remotes → Jira. Everything else, including work-adjacent notes with no Jira ticket, → GitHub (`memex`, domain tag `work-primary`).

## GitHub Issues

Default for all personal work — routing returns `github-current:*` for repo-scoped captures or `memex` for cross-cutting ones.

- **Task index / issues log**: paths under personal KB vault — see vault `AGENTS.md` (`Raw/_task-index.jsonl`)
- **Template**: user story format — see `issue-create` SKILL.md

### Deprecated: personal KB GitHub Projects

`gh project item-add` for domain → GitHub Project routing is **deprecated** for new tasks.

## GitHub account management

When multiple `gh` accounts are active, the work account is often the default and cannot access personal repos.

```bash
export GITHUB_PERSONAL_USER=<personal-github-username>
export SKILLS_WORK_ORGS=<org1>,<org2>
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

**Force GitHub routing:** `export ISSUE_ROUTE=github` before detect-context.sh (player reports, PR-linked issues).

Prefer `--repo <owner/repo>` explicitly when SSH remotes use a multi-account host alias.

## Task index

Append a record for every issue created (`system`: `github`, `jira`, `gitlab`). Update `status` when tasks close. Paths live in the personal KB repo.

GitHub records: `system: "github"`, `repo: "<owner/repo>"`, `domain: "<tag>"` (see Domain tags above).
