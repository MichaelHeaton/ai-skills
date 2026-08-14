# AGENTS.md — ai-skills

> **Portable AI workspace** — read this first in any tool (Cursor, Claude Code, etc.).
> Principles: [principles/](principles/). Claude overlay: [CLAUDE.md](CLAUDE.md).

## What this is

A public, versioned home for **multi-AI** skills and conventions. The repo is growing incrementally; see [docs/ROADMAP.md](docs/ROADMAP.md) for what exists vs planned.

## Repository layout (target)

| Path | Role |
| ------ | ------ |
| `principles/` | Universal rules (present) |
| `config/`, `categories/` | Templates, `sanitize.json`, placeholder tags |
| `docs/` | Guides, multi-AI setup, runbook stubs — see [docs/README.md](docs/README.md) |
| `ai/claude/skills/` | Claude Code skills (present — 48 skills) |
| `ai/cursor/rules/` | Cursor rules (present — deployed to `~/.cursor/rules/`) |
| `scripts/` | Phase 0, import, manifests — `make help` |

## Where skills live today

**Canonical tree:** `ai/claude/skills/<name>/SKILL.md` in this repo.

**Runtime deploy:** `make install-system` (copy-only) → `~/.claude/skills/<name>/` and `~/.cursor/rules/*.mdc`. If you edited under `~/.claude/` or `~/.cursor/rules/` first, run `make sync-from-system` before reinstalling. See [principles/deployment.md](principles/deployment.md).

## Related repositories

| Repo | Role |
| ------ | ------ |
| [claude-skills](https://github.com/MichaelHeaton/claude-skills) | Legacy mirror; deploy from **ai-skills** |
| [Memex](https://github.com/MichaelHeaton/memex) | Maintainer’s **personal second brain** (PKM vault) — project name, not a generic product |
| [workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops) | Ansible install on author’s Macs (`make apply`) |

See [docs/guides/memex-and-related-repos.md](docs/guides/memex-and-related-repos.md).

## Private configuration

Employer- and domain-specific values belong in **`~/.config/ai-skills/local.json`** (and optional private answer files — see [principles/domains.md](principles/domains.md)). Copy from [`config/local.template.json`](config/local.template.json). See [`docs/guides/local-config.md`](docs/guides/local-config.md). Never commit filled copies.

## Guides

| Guide | Purpose |
| ------- | --------- |
| [docs/multi-ai.md](docs/multi-ai.md) | Claude + Cursor layout |
| [docs/guides/skill-conventions.md](docs/guides/skill-conventions.md) | Skill naming and `SKILL.md` structure |
| [docs/guides/branching.md](docs/guides/branching.md) | Branch + PR rules by repo type |
| [docs/guides/local-config.md](docs/guides/local-config.md) | Private `local.json` |
| [docs/guides/memex-and-related-repos.md](docs/guides/memex-and-related-repos.md) | Memex naming, workstation install |

## Principles (read order)

1. [principles/core.md](principles/core.md)
2. [principles/security.md](principles/security.md)
3. [principles/domains.md](principles/domains.md)
4. [principles/deployment.md](principles/deployment.md)
5. [principles/versioning.md](principles/versioning.md)
6. [principles/token-efficiency.md](principles/token-efficiency.md)

## Security

See [principles/security.md](principles/security.md).

## Legacy source

Skill bodies were imported from **claude-skills**. Edit here, deploy with `make install-system`. Re-run `make import-legacy` only when pulling changes from the legacy repo during migration.
