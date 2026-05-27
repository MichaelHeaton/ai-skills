# AGENTS.md — ai-skills

> **Portable AI workspace** — read this first in any tool (Cursor, Claude Code, etc.).
> Principles: [principles/](principles/). Claude overlay: [CLAUDE.md](CLAUDE.md). Claude tree: [ai/claude/README.md](ai/claude/README.md).

## What this is

Versioned **skills** (markdown workflows) and shared conventions. Public repo — employer-specific values live in **`~/.config/ai-skills/local.json`** only.

Legacy content was imported from [claude-skills](https://github.com/MichaelHeaton/claude-skills) (to be archived after cutover).

## Quick start

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
cd ai-skills
# After PR 2: make install-system
```

**Phase 0** (one-time from legacy symlink setup): `make unlink-legacy`

## Architecture

```
ai/claude/skills/<name>/SKILL.md   # Claude Code skills
ai/claude/hooks/                   # Claude pre-tool-use hooks
ai/claude/memory/                  # Project memory (deployed copy)
principles/                        # Source of truth for all AIs
docs/guides/                       # Branching, local config, conventions
config/local.template.json         # Template → ~/.config/ai-skills/local.json
```

| Path | Role |
|------|------|
| [principles/core.md](principles/core.md) | Universal rules |
| [principles/deployment.md](principles/deployment.md) | Install, sync, manifests |
| [principles/security.md](principles/security.md) | Public-repo safety |
| [docs/guides/local-config.md](docs/guides/local-config.md) | `local.json` schema |
| [docs/guides/skill-conventions.md](docs/guides/skill-conventions.md) | Naming and SKILL.md structure |

## Local configuration

| File | Purpose |
|------|---------|
| `~/.config/ai-skills/local.json` | Primary private config |
| `~/.config/ai-skills/accounts.shell` | Shell exports for git identity scripts |
| `config/local.template.json` | Public template (never commit filled copy) |

## Workflows

| Task | Command / skill |
|------|-----------------|
| Deploy to Claude | `make install-system` (PR 2) |
| Pull edits from `~/.claude` | `make sync-from-system` (PR 2) |
| New skill | `skill-create` skill |
| Git commit / PR | `git-ops` skill |
| Import from legacy repo | `make import-legacy` |

## Security

See [principles/security.md](principles/security.md). Before every PR: no internal URLs, project keys, or coworker names in the diff.

## Gotchas

- **Reload** after skill edits — new Claude session required
- **`name` frontmatter** must match directory name
- **Edit in repo** preferred; use sync-back if you edited under `~/.claude/`
- **Cursor** — open this repo in workspace or see `ai/cursor/README.md` (PR 4)
