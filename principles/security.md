---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Security principles

This repo is **public**. Treat every commit as publishable.

## Never commit

- Coworker names, employer emails, LDAP IDs
- Internal project keys, `*.corp.*` URLs, SharePoint links
- Vault paths, policy names, credential hints
- Filled `config/local.json`, `accounts.shell`, or `leak-patterns`

## Use instead

- Placeholders from [categories/tags.yaml](../categories/tags.yaml) (e.g. `[jira_project_key]`)
- Values in `~/.config/ai-skills/local.json`
- Optional private regex: `~/.config/ai-skills/leak-patterns`

## Before commit

1. Run `make validate-public` when available (PR 3+)
2. Review staged diff for accidental PII
3. After `sync-from-system --apply`, re-scan — system edits can introduce leaks

## Sanitization

Rules in [config/sanitize.json](../config/sanitize.json) define replacements for scrubbing drafts. Pre-commit enforces scans in PR 3+.
