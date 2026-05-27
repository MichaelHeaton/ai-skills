# Local configuration

Public skills use placeholders. Your machine holds the real values in **`~/.config/ai-skills/local.json`** (primary) and optionally **`accounts.shell`** for bash/direnv.

## Why JSON (not committed `.env`)

| File | Claude `block-env-read` | Best for |
|------|------------------------|----------|
| `local.json` | Allowed | Multiple accounts/roles, Jira, weekly report targets |
| `accounts.shell` | Allowed (not `*.env`) | `export` vars for `setup-account.sh`, direnv |
| Repo `.env` / skill `.env` | **Blocked** | Credentials only — never put AI config here |

JSON handles **N git identities** in one `accounts` object. JSON is easier for scripts (`jq`) and validation.

## Files

| File | Purpose |
|------|---------|
| `~/.config/ai-skills/local.json` | Primary — copy from `config/local.template.json` |
| `~/.config/ai-skills/accounts.shell` | Shell exports — copy from `config/accounts.shell.template` |
| `~/.config/ai-skills/leak-patterns` | Optional private regex list for pre-commit |
| `config/local.template.json` | Public template in this repo |
| `config/local.json` | Optional per-checkout override (gitignored) |

`make install-system` (PR 2) creates `local.json` and `accounts.shell` if missing.

## Accounts model (`local.json`)

```json
"accounts": {
  "personal": { "github_user": "...", "remote_match": ["github.com-personal"] },
  "work": { "github_user": "...", "github_orgs": ["org-slug"], "remote_match": ["..."] },
  "client_contract": { "gitlab_host": "gitlab.com", "remote_match": ["gitlab.com"] }
}
```

Account keys are arbitrary in your **private** `local.json`. The public **template** uses generic key names only.

## Placeholders in skills

Legacy `${VAR}` style is being migrated to `[tag_name]` per [categories/tags.yaml](../../categories/tags.yaml).

| Placeholder | JSON path |
|-------------|-----------|
| `${JIRA_PROJECT_KEY}` / `[jira_project_key]` | `jira.project_key` |
| `${JIRA_BASE_URL}` / `[jira_base_url]` | `jira.base_url` |
| `${WORK_DOCS_REPO}` | `repos.work_docs` |
| `${GITHUB_PERSONAL_USER}` | `accounts.personal.github_user` |

## Weekly reports

Skill **`weekly-report`** — routes via `weekly_reports` in your private `local.json`.

## Migration from claude-skills

If you used `~/.config/claude-skills/`, run `make unlink-legacy` (Phase 0) to copy into `~/.config/ai-skills/`.

## Storage

Never commit filled `local.json`, `accounts.shell`, or `leak-patterns`.
