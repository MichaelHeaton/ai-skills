# Local configuration

Public skills use placeholders. Your machine holds the real values in **`~/.config/ai-skills/local.json`** (primary) and optionally **`accounts.shell`** for bash/direnv.

## Why JSON (not committed `.env`)

| File | Claude `block-env-read` | Best for |
|------|------------------------|----------|
| `local.json` | Allowed | Multiple accounts/roles, Jira, weekly report targets |
| `accounts.shell` | Allowed (not `*.env`) | `export` vars for `setup-account.sh`, direnv |
| Repo `.env` / skill `.env` | **Blocked** | Credentials only — never put AI config here |

JSON handles **N git identities** (personal, work, client contract, future) in one `accounts` object. YAML works too; JSON is easier for scripts (`jq`) and validation.

## Files

| File | Purpose |
|------|---------|
| `~/.config/ai-skills/local.json` | Primary — copy from `config/local.template.json` |
| `~/.config/ai-skills/accounts.shell` | Shell exports — copy from `config/accounts.shell.template` |
| `~/.config/ai-skills/leak-patterns` | Optional private regex list for pre-commit (see `config/leak-patterns.README`) |
| `config/local.template.json` | Public template |

`make install-system` (when added) will create `local.json` and `accounts.shell` if missing.

## Accounts model (`local.json`)

```json
"accounts": {
  "personal": { "github_user": "...", "remote_match": ["github.com-personal"] },
  "work": { "github_user": "...", "github_orgs": ["org-slug"], "remote_match": ["..."] },
  "client_contract": { "gitlab_host": "gitlab.com", "remote_match": ["gitlab.com"] }
}
```

Account keys are arbitrary in your **private** `local.json` — you may use descriptive `label` values (employer name, client name). The public **template** uses generic key names only.

`setup-account.sh` (when present) picks the account whose `remote_match` substring appears in `git remote get-url origin`.

## Placeholders in skills

| Placeholder | JSON path |
|-------------|-----------|
| `${JIRA_PROJECT_KEY}` | `jira.project_key` |
| `${JIRA_BASE_URL}` | `jira.base_url` |
| `${WORK_DOCS_REPO}` | `repos.work_docs` |
| `${GITHUB_PERSONAL_USER}` | `accounts.personal.github_user` |

Tag definitions: [categories/tags.yaml](../../categories/tags.yaml).

## Weekly reports

Single skill: **`weekly-report`** — routes via `weekly_reports.client_contract` (deck) and `weekly_reports.work_team` (wiki PPP) in your private `local.json`.

## Migration from `~/.config/claude-skills/`

If you already have `local.json` or `local.yaml` under `~/.config/claude-skills/`, copy values into `~/.config/ai-skills/local.json` once, then rely on the new path only.

## Storage

Never commit filled `local.json`, `accounts.shell`, or `leak-patterns`. workstation-devops will only run install targets that copy templates.
