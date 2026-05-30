---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
---

# Issue routing rules

Run `scripts/detect-context.sh` from the current working directory. All four `issue-*` skills and `memex-dump` use this logic.

**Notion SoT (author setup):** `System → Repositories` (`collection://6f44da4e-bb6b-433a-a9a7-c1a6f9d93579`) holds `Ticket System` and `Linear Project` per repo. `references/repo-routing.json` mirrors it for shell scripts — refresh when Notion changes.

Read `linear.*` and `routing.*` from `~/.config/ai-skills/local.json` when values are not in the repo map.

## Routing targets

| Output | Meaning | Where issues go |
| --- | --- | --- |
| `jira-work` | Remote matches `routing.work_github_orgs` or `SKILLS_WORK_ORGS` | Jira — `jira.project_key` in local.json |
| `linear:<project>` | Personal / cross-cutting work (default) | Linear — `linear.team` in local.json |
| `github-current:<owner/repo>` | Explicit GitHub routing only | GitHub Issues in that repo |
| `gitlab-current:<namespace/repo>` | GitLab remote | GitLab Issues in that repo |

**Deprecated:** `memex` → use `linear:<project>`. Personal KB GitHub Issues is no longer the catch-all for new tasks.

### When to use GitHub vs Linear (personal repos)

| Situation | Route |
| --- | --- |
| Default capture in any personal repo | `linear:<project>` — do **not** auto-create GitHub Issues in-repo |
| PR-linked dev work where GitHub workflow matters | `github-current:<repo>` when user asks for GitHub or repo `Ticket System` = GitHub in Notion |
| Minecraft modpack **dev** | `linear:Minecraft Modpacks` |
| Minecraft **player / tester / playtest** report | `github-current:<modpack-repo>` (`export ISSUE_ROUTE=github`) |
| No git remote / brain dump | `linear:<project>` from domain |

## Linear project map

| Linear project | Use for | Domain tag (task index) |
| --- | --- | --- |
| Adobe | Work-adjacent without a Jira ticket | `work-primary` |
| UV Cyber | Contractor ops, hiring, reporting | `client-contract` |
| Homelab | Homelab / infra (default even when a repo exists) | `homelab` |
| AI Skills | `ai-skills`, agent rules, MCP (`claude-skills` legacy until archived) | `learning` |
| Workstation DevOps | Dotfiles, dev machine setup | `homelab` |
| Minecraft Modpacks | Modpack **dev** work | `personal` |
| MTB | Coaching, NICA, trails | `mtb` |
| Personal | Life admin, learning, misc | `personal` |

**Default skill repo:** `ai-skills`. `claude-skills` is legacy — archive after migration completes. Both map to Linear **AI Skills** until then.

### Linear MCP

- **Create:** `save_issue` — `team` from `linear.team`, `project`, `title`, `description`
- **List:** `list_issues` — filter by `team`, `project`, `assignee: "me"`
- **Get:** `get_issue` — id like `SR-123`
- **Update:** `save_issue` (with `id`), `save_comment`, `state`

Priority map: `high` → 2, `medium` → 3, `low` → 4.

## Jira (work context)

Read `~/.config/ai-skills/local.json`:

- **Project key**: `jira.project_key`
- **Default type**: `jira.default_issue_type` (usually `Story`)
- **Never create Epics** unless your org allows it — see `jira.epic_owners_note`
- **Epic linking**: `jira.epic_link_field` when the user names an epic
- **Updates go in comments**, not body edits

Work org remotes → Jira. Linear **Adobe** only when no Jira ticket applies.

## GitHub Issues (explicit repo only)

Use when routing returns `github-current:*` or the user explicitly requests a GitHub issue / player report.

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

**Force GitHub routing:** `export ISSUE_ROUTE=github` before detect-context (player reports, PR-linked issues).

Prefer `--repo <owner/repo>` explicitly when SSH remotes use a multi-account host alias.

## Task index

Append a record for every issue created (`system`: `linear`, `github`, `jira`, `gitlab`). Update `status` when tasks close. Paths live in the personal KB repo.

Linear records: `system: "linear"`, `repo: null`, `id: "SR-123"`, `project: "<Linear project name>"`.
