# AGENTS.md — ai-skills

> **Portable AI workspace** — read this first in any tool (Cursor, Claude Code, etc.).
> Principles: [principles/](principles/). Claude overlay: [CLAUDE.md](CLAUDE.md).

## What this is

A public, versioned home for **multi-AI** skills and conventions. This repo is being built in **small PRs**; not everything is present yet.

| Milestone | Status |
|-----------|--------|
| PR-A (this) | `principles/`, `AGENTS.md`, entry docs |
| PR-B | `config/`, `categories/` |
| PR-C | `docs/guides/` |
| PR-D | Scripts (`unlink-legacy`, import tooling) |
| PR-F | `ai/claude/skills/` import from claude-skills |
| PR-G | `install-system`, `sync-from-system` |

## Where skills live today

Until **PR-F**, skills remain in [claude-skills](https://github.com/MichaelHeaton/claude-skills):

```
claude-skills/skills/<name>/SKILL.md  →  ~/.claude/skills/<name>/
```

After PR-F:

```
ai-skills/ai/claude/skills/<name>/SKILL.md  →  ~/.claude/skills/<name>/  (via install-system)
```

## Private configuration

Employer-specific values belong in **`~/.config/ai-skills/local.json`** (created from template in PR-B). Never commit filled copies.

## Principles (read order)

1. [principles/core.md](principles/core.md) — purpose and phased layout
2. [principles/security.md](principles/security.md) — public-repo rules
3. [principles/deployment.md](principles/deployment.md) — copy-only install (upcoming)
4. [principles/versioning.md](principles/versioning.md) — semver and tiers
5. [principles/token-efficiency.md](principles/token-efficiency.md) — token discipline

## Security

See [principles/security.md](principles/security.md). No internal URLs, project keys, or coworker names in git.

## Legacy

Content is imported from **claude-skills** in PR-F. That repo stays the runtime source until **install-system** (PR-G) deploys from here.
