# Local configuration

Public skills use placeholders. Your machine holds the real values in **`~/.config/ai-skills/local.json`** (primary) and optionally **`accounts.shell`** for bash/direnv.

## Why JSON (not committed `.env`)

| File | Claude `block-env-read` | Best for |
| ------ | ------------------------ | ---------- |
| `local.json` | Allowed | Multiple accounts/roles, Jira, weekly report targets |
| `accounts.shell` | Allowed (not `*.env`) | `export` vars for `setup-account.sh`, direnv |
| Repo `.env` / skill `.env` | **Blocked** | Credentials only — never put AI config here |

JSON handles **N git identities** (personal, work, client contract, future) in one `accounts` object. YAML works too; JSON is easier for scripts (`jq`) and validation.

## Files

| File | Purpose |
| ------ | --------- |
| `~/.config/ai-skills/local.json` | Primary — copy from `config/local.template.json` |
| `~/.config/ai-skills/accounts.shell` | Shell exports — copy from `config/accounts.shell.template` |
| `~/.config/ai-skills/leak-patterns` | Optional private regex list for pre-commit (see `config/leak-patterns.README`) |
| `config/local.template.json` | Public template |

`make install-system` creates `local.json` from the template if missing (never overwrites a filled file).

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

## Routing

| Key | Purpose |
| ----- | --------- |
| `routing.personal_kb_github` | `owner/repo` for your personal knowledge base on GitHub (second brain, vault, PKM — any name) |
| `routing.work_github_orgs` | Org slugs used to detect work-scoped GitHub repos |

Paths under `weekly_reports.*.vault_format_ref` and `vault_agent_ref` are **relative to that repo’s tree**, not to this skills repo.

## Placeholders in skills

| Placeholder | JSON path |
| ------------- | ----------- |
| `${JIRA_PROJECT_KEY}` | `jira.project_key` |
| `${JIRA_BASE_URL}` | `jira.base_url` |
| `${WORK_DOCS_REPO}` | `repos.work_docs` |
| `${GITHUB_PERSONAL_USER}` | `accounts.personal.github_user` |

Tag definitions: [categories/tags.yaml](../../categories/tags.yaml).

## Comms-write private examples

Optional block for `comms-write` example resolution:

| Key | Purpose |
| ----- | --------- |
| `comms_write.examples_root` | Absolute path to `.../examples/` (overrides everything) |
| `comms_write.memex_repo_path` | Path to the **maintainer’s Memex** vault on disk (example default — use your own PKM repo) |
| `comms_write.examples_relative` | Path under that repo (default: `ai/claude/skills/comms-write-context/examples`) |

Public skill repos ship **stubs only**; full templates live in a **private** vault. The author keeps theirs in [Memex](https://github.com/MichaelHeaton/memex) — see [memex-and-related-repos.md](memex-and-related-repos.md).

## Weekly reports

Single skill: **`weekly-report`** — routes via `weekly_reports.client_contract` (deck) and `weekly_reports.work_team` (wiki PPP) in your private `local.json`. Use `vault_format_ref` / `vault_agent_ref` for paths inside your personal KB repo.

## Migration from `~/.config/claude-skills/`

If you already have `local.json` or `local.yaml` under `~/.config/claude-skills/`, copy values into `~/.config/ai-skills/local.json` once, then rely on the new path only.

If your private file still has `routing.memex_github`, rename it to `routing.personal_kb_github` (same `owner/repo` value). Likewise `memex_format_ref` → `vault_format_ref` and `memex_agent_ref` → `vault_agent_ref` under `weekly_reports`.

## Storage

Never commit filled `local.json`, `accounts.shell`, or `leak-patterns`. workstation-devops will only run install targets that copy templates.
