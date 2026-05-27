# AGENTS.md — ai-skills

> **Portable AI workspace** — read this first in any tool (Cursor, Claude Code, etc.).
> Principles: [principles/](principles/). Claude overlay: [CLAUDE.md](CLAUDE.md).

## What this is

A public, versioned home for **multi-AI** skills and conventions. The repo is growing incrementally; see [docs/ROADMAP.md](docs/ROADMAP.md) for what exists vs planned.

## Repository layout (target)

| Path | Role |
|------|------|
| `principles/` | Universal rules (present) |
| `config/`, `categories/` | Templates, `sanitize.json`, placeholder tags |
| `docs/` | Guides and runbooks (`docs/guides/` when present) |
| `ai/claude/skills/` | Claude Code skills (planned) |
| `ai/cursor/rules/` | Cursor rules (planned) |
| `scripts/` | Install, sync, manifests (planned) |

## Where skills live today

Skills are **not in this repository yet**. Use [claude-skills](https://github.com/MichaelHeaton/claude-skills):

```
claude-skills/skills/<name>/SKILL.md  →  ~/.claude/skills/<name>/
```

When `ai/claude/skills/` exists here:

```
ai/claude/skills/<name>/SKILL.md  →  ~/.claude/skills/<name>/  (via make install-system)
```

## Private configuration

Employer-specific values belong in **`~/.config/ai-skills/local.json`**. Copy from [`config/local.template.json`](config/local.template.json). See [`docs/guides/local-config.md`](docs/guides/local-config.md). Never commit filled copies.

## Principles (read order)

1. [principles/core.md](principles/core.md)
2. [principles/security.md](principles/security.md)
3. [principles/deployment.md](principles/deployment.md)
4. [principles/versioning.md](principles/versioning.md)
5. [principles/token-efficiency.md](principles/token-efficiency.md)

## Security

See [principles/security.md](principles/security.md).

## Legacy source

Skill bodies will be imported from **claude-skills**. That repo remains the runtime source until copy-only install from here is implemented.
