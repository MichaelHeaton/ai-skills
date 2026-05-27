---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Issue routing rules

Run `scripts/detect-context.sh` from the current working directory. All four `issue-*` skills use this logic.

## Routing targets

| Output | Meaning | Where issues go |
|---|---|---|
| `jira-work` | Remote matches an org in `routing.work_github_orgs` (or `SKILLS_WORK_ORGS`) | Jira — project from `jira.project_key` in local.json |
| `github-current:<owner/repo>` | Personal or non-work GitHub remote | GitHub Issues in that repo |
| `memex` | No remote / unrecognized | GitHub Issues in `routing.personal_kb_github` |

## Jira (work context)

Read `~/.config/ai-skills/local.json`:

- **Project key**: `jira.project_key` (e.g. `PROJ-12345` in the template — use your real key privately)
- **Default type**: `jira.default_issue_type` (usually `Story`)
- **Never create Epics** unless your org allows it — see `jira.epic_owners_note`
- **Epic linking**: `jira.epic_link_field` when the user names an epic
- **Updates go in comments**, not body edits — treat the description as definition of done

If no existing work ticket fits, create a personal-kb issue tagged `needs-jira-triage` for later linking.

## GitHub Issues (personal KB or current repo)

- **Personal KB repo**: `routing.personal_kb_github` (clone path: `comms_write.memex_repo_path` or your usual Projects path)
- **Task index / issues log**: paths under that vault — see the vault’s `AGENTS.md` (e.g. `Raw/_task-index.jsonl`)
- **Template**: user story format — see `issue-create` SKILL.md

### Domain → GitHub Project (optional)

If you use GitHub Projects for domain labels, define mapping in private `local.json` (example shape):

```json
"github_projects": {
  "work-primary": { "name": "Work", "number": 0 },
  "client-contract": { "name": "Client", "number": 0 },
  "homelab": { "name": "HomeLab", "number": 0 },
  "personal": { "name": "Personal", "number": 0 }
}
```

Use `categories/tags.yaml` domain tokens (`work-primary`, `client-contract`, `personal`, …) — not employer names in the public repo.

Issues in other repos use that repo’s own project board, if any.

## GitHub account management

When multiple `gh` accounts are active, the work account is often the default and cannot access personal repos.

**Required env vars** (shell profile):

```bash
export GITHUB_PERSONAL_USER=<personal-github-username>
export SKILLS_WORK_ORGS=<org1>,<org2>   # comma-separated; match → jira-work
```

**Before `gh` commands targeting the personal KB or `github-current:*` personal repos:**

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

Prefer `--repo <owner/repo>` explicitly when SSH remotes use a multi-account host alias.

## Task index

Append a record for every issue created (GitHub or Jira). Update `status` when tasks close. Paths live in your personal KB repo — not in this public skills repo.
