# Issue Routing Rules

Run `scripts/detect-context.sh` from the current working directory to get the routing target. All four issue-* skills use this same logic.

## Routing targets

| Output | Meaning | Where issues go |
|---|---|---|
| `jira-cesss` | Repo in any org listed in `$SKILLS_WORK_ORGS` | Jira, project CESSS, type Story |
| `github-current:<owner/repo>` | Personal GitHub repo | GitHub Issues in that repo |
| `memex` | No remote / unrecognized | GitHub Issues in `${GITHUB_PERSONAL_USER}/memex` |

## Jira CESSS rules

- **Project key**: `CESSS`
- **Default type**: `Story` — always use Story; the team does not want Tasks created by AI
- **Never create Epics** — managers only (Damon Gentry, Drew Wright)
- **Epic linking**: `customfield_11800` with epic key (e.g. `CESSS-12345`)
- **Required fields**: `project.key`, `summary`, `issuetype.name`, `description`
- **Updates go in comments**, not body edits — Jira body is the definition of done

If no existing CESSS ticket fits the work, create a Memex issue tagged `needs-jira-triage` so it can be linked or converted later.

## GitHub Issues (Memex or current repo)

- **Memex repo**: `${GITHUB_PERSONAL_USER}/memex` (local: `~/Projects/personal/memex/`)
- **Task index**: `~/Projects/personal/memex/Raw/_task-index.jsonl`
- **Issues log**: `~/Projects/personal/memex/Raw/_GitHub-Issues-log.jsonl`
- **Template**: user story format — see issue-create SKILL.md §2

### Domain → GitHub Project routing

| Domain | Project name | Project number |
|---|---|---|
| adobe | Adobe | 8 |
| uv-cyber | UV Cyber | 10 |
| homelab | HomeLab | 7 |
| learning | Learning | 11 |
| personal | Personal | 13 |
| mtb | MTB | 9 |
| iot | IoT | 12 |

Issues created in non-Memex repos don't get added to these projects (they live in that repo's own project board, if any).

## GitHub account management

When two `gh` accounts are active (e.g. a work EMU and a personal account), the work account is typically the default. It cannot access personal repos — operations fail with a 404 or auth error.

**Required env vars** — set these in `~/.zshrc` or `~/.bashrc`:

```bash
export GITHUB_PERSONAL_USER=<your-personal-github-username>
export SKILLS_WORK_ORGS=<org1>,<org2>   # comma-separated; any match routes to jira-cesss
```

**Before any `gh` command targeting Memex or a `github-current:*` personal repo**, export the personal token:

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

This avoids changing the globally active account — `GH_TOKEN` is session-scoped, `gh auth switch` is global.

**SSH alias note:** If the Memex git remote uses a multi-account SSH alias (e.g. `github.com-personal:${GITHUB_PERSONAL_USER}/memex.git`), the `gh` CLI may fail to resolve the repo from the remote even after setting `GH_TOKEN`. Always pass `--repo <owner/repo>` explicitly rather than relying on remote detection.

## Task index notes

The task index at `~/Projects/personal/memex/Raw/_task-index.jsonl` is a cross-system locator — append a record for every issue created, regardless of system (GitHub or Jira). Update `status` in place when tasks close.
