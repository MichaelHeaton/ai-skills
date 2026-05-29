---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: human
---

# Security principles

This repository is **public**. Treat every commit as publishable.

## Never commit

- Coworker names, employer emails, LDAP IDs
- Internal project keys, `*.corp.*` URLs, SharePoint links
- Vault paths, policy names, credential hints
- Filled `config/local.json`, `accounts.shell`, or private leak-pattern lists

## Use instead

- Placeholder tokens from `categories/tags.yaml` (when present)
- Values in `~/.config/ai-skills/local.json` and optional domain answer files — see [domains.md](domains.md)
- Optional private regex: `~/.config/ai-skills/leak-patterns`

## Before every pull request

Review the diff for accidental PII or internal URLs. Automated scans will be added with pre-commit hooks later.
