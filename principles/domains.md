---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: human
---

# Domain awareness

This repo is **public**. Skills must work for any user without baking in one employer, client, or product. **Domain awareness** is how portable skills meet proprietary reality on each machine.

## What a domain is

A **domain** is an organizational or life context the user works in — for example personal, primary employer, client contract, volunteer program, or homelab. Domains are **labels in private config**, not hardcoded names in git.

Skills and agents should:

- Know **which domain applies** to the current task (repo remote, user intent, `local.json` routing).
- Use **placeholders** in public skill text (`categories/tags.yaml`, `${JIRA_PROJECT_KEY}`, etc.).
- Read **real values** only from private answer files on the machine.
- **Never invent** internal URLs, project keys, channel names, or people.

## Fictional examples in public content

Committed skills, principles, and cursor rules must **not** use real employer or client names as illustrations. Use the shared fiction from [categories/tags.yaml](../categories/tags.yaml):

| Use in git | Meaning |
| ---------- | ------- |
| **Acme Corp** | Example company display name (`company_name`) |
| **`acme`** | Example domain slug (`domain_slug`) — keys in `local.json`, folder names |
| **`acme-cursor-rules`** | Example domain rule-pack repo (`{domain_slug}-cursor-rules`) |
| **Jane Doe**, **PROJ-12345**, **wiki.example.com** | Other placeholders in `tags.yaml` |

Your filled `local.json` uses real labels and slugs privately; only templates and docs in this repo use Acme.

## Every skill is domain-aware

All skills in `ai/claude/skills/` should follow this model:

| Layer | In git (public) | On machine (private) |
| ------- | ----------------- | ---------------------- |
| Procedure | `SKILL.md` — generic steps, triggers, placeholders | — |
| Routing | `references/routing.md`, `categories/tags.yaml` | `local.json` → `accounts`, `routing`, `jira`, `repos` |
| Examples | Stubs only when examples would leak context | Full templates under a private vault or `comms_write.examples_root` |
| Security / lint rules | `principles/security.md`, universal cursor rules | `{domain}-cursor-rules` repo when open in workspace |
| Extra domain answers | Documented keys in `config/local.template.json` | Filled `local.json`; optional `~/.config/ai-skills/domains/<slug>.json` |

**Cross-cutting skills** (`git-ops`, `skill-review`, `lean-context`) still apply: they must not assume a single employer and must point at `local.json` when routing depends on context.

### Skill author checklist

- [ ] No employer names, internal hostnames, or real ticket keys in `SKILL.md` or committed `references/`.
- [ ] Document which `local.json` keys the skill reads (or add them to `config/local.template.json`).
- [ ] Use placeholder tokens from `categories/tags.yaml` in examples.
- [ ] If the skill needs rich private examples, ship **stubs** in git and resolve full content from `local.json` paths (see `comms-write`).
- [ ] If the skill only makes sense in one product scope, say so in `description` — do not encode the org name in the skill directory name unless unavoidable.

## Private answer files (never committed)

Proprietary domain information lives **only** on the user's machine (or private repos), never in **ai-skills** or other public trees.

| File | Purpose |
| ------ | --------- |
| `~/.config/ai-skills/local.json` | **Primary** — accounts, Jira, routing, repo paths, weekly-report targets |
| `~/.config/ai-skills/accounts.shell` | Optional shell exports for git identity / direnv |
| `~/.config/ai-skills/leak-patterns` | Optional private regex list for pre-commit |
| `~/.config/ai-skills/domains/<slug>.json` | Optional per-domain overlay (same schema fragments as `local.json`; merge in skill or script) |
| Private vault / KB repo | Long-form examples, meeting context, employer runbooks (e.g. comms-write templates) |
| `{domain}-cursor-rules` | Cursor rules and security packs scoped to one domain |

`make install-system` creates `local.json` from the template **if missing** — it **never overwrites** a filled file. `make sync-from-system` does **not** pull `local.json`, secrets, or private domain files into this repo.

## Domain-specific rule packs

When a workspace includes a repo named **`{domain}-cursor-rules`**, treat it as the domain's Cursor rule pack (security, stack conventions, review norms). Apply rules from packs that match the project being edited. Universal rules in `principles/` and `ai/cursor/rules/` still apply.

## Detecting the active domain

Use existing signals — do not guess proprietary values:

1. **Git remote** — match against `accounts.*.remote_match` in `local.json` (`issue-create` / `repo-setup` patterns).
2. **User statement** — "for work", "Acme contract", "personal KB" (real names are fine in chat; do not copy them into public commits).
3. **Repo in workspace** — `{domain}-cursor-rules`.
4. **Ambiguity** — ask once; prefer the narrowest domain that fits.

## Related docs

- [docs/guides/local-config.md](../docs/guides/local-config.md) — `local.json` schema and placeholders
- [docs/guides/skill-conventions.md](../docs/guides/skill-conventions.md) — naming and layout
- [principles/security.md](security.md) — what must never be committed
- [categories/tags.yaml](../categories/tags.yaml) — placeholder registry
