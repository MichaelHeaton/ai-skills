# Issue Routing Rules

Run `scripts/detect-context.sh` from the current working directory to get the routing target. All four issue-* skills use this same logic.

**Before routing:** read `~/.config/claude-skills/local.yaml` when it exists ([references/local-config.md](../../../references/local-config.md)).

## Routing targets

| Output | Meaning | Where issues go |
|---|---|---|
| `jira-work` | Repo in any org listed in `$SKILLS_WORK_ORGS` | Jira Story in `${JIRA_PROJECT_KEY}` |
| `github-current:<owner/repo>` | Personal GitHub repo | GitHub Issues in that repo |
| `gitlab-current:<namespace/repo>` | GitLab repo | GitLab Issues in that project |
| `memex` | No remote / unrecognized | GitHub Issues in `${GITHUB_PERSONAL_USER}/memex` |

## Jira work project rules

Values come from `local.yaml` (`jira.*`) or env (`SKILLS_JIRA_*`).

- **Project key**: `${JIRA_PROJECT_KEY}` (e.g. `WORK`)
- **Default type**: `Story` — prefer Story over Task unless the user asks otherwise
- **Never create Epics** — see `jira.epic_owners_note` in local config (managers only)
- **Epic linking**: `${JIRA_EPIC_LINK_FIELD}` with epic key (e.g. `${JIRA_EXAMPLE_KEY}`)
- **Required fields**: `project.key`, `summary`, `issuetype.name`, `description`
- **Updates go in comments**, not body edits — Jira body is the definition of done

If no existing work ticket fits, create a Memex issue tagged `needs-jira-triage` so it can be linked or converted later.

## GitHub Issues (Memex or current repo)

- **Memex repo**: `${GITHUB_PERSONAL_USER}/memex` (local path in `local.yaml` → `repos` or your standard `~/Projects/personal/memex/`)
- **Task index**: `~/Projects/personal/memex/Raw/_task-index.jsonl`
- **Issues log**: `~/Projects/personal/memex/Raw/_GitHub-Issues-log.jsonl`
- **Template**: user story format — see issue-create SKILL.md §2

### Domain → GitHub Project routing

Project numbers are personal metadata — configure in `local.yaml` under `github_projects` if you add them, or infer from Memex conventions when working in that vault.

| Domain | Project name (example) |
|---|---|
| adobe | Adobe |
| uv-cyber | UV Cyber |
| homelab | HomeLab |
| learning | Learning |
| personal | Personal |
| mtb | MTB |
| iot | IoT |

Issues created in non-Memex repos don't get added to these projects (they live in that repo's own project board, if any).

## GitHub account management

When two `gh` accounts are active (work EMU and personal), the work account may be the default and cannot access personal repos.

**Required env vars** — set in `~/.config/claude-skills/accounts.shell` or `~/.zshrc`:

```bash
export GITHUB_PERSONAL_USER=<your-personal-github-username>
export SKILLS_WORK_ORGS=<org1>,<org2>   # comma-separated; any match routes to jira-work
```

**Before any `gh` command targeting Memex or a `github-current:*` personal repo**, export the personal token:

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

**SSH alias note:** If the Memex git remote uses a multi-account SSH alias (e.g. `github.com-personal:...`), pass `--repo <owner/repo>` explicitly rather than relying on remote detection.

## Task index notes

The task index at `~/Projects/personal/memex/Raw/_task-index.jsonl` is a cross-system locator — append a record for every issue created, regardless of system (GitHub, GitLab, or Jira). Update `status` in place when tasks close.
