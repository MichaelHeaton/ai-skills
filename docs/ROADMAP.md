---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Roadmap

Migration from [claude-skills](https://github.com/MichaelHeaton/claude-skills) to **ai-skills** in small, reviewable steps. Update this file as work lands; other docs describe **current state**, not PR numbers.

## Present in repo

- [x] `principles/` — universal rules
- [x] `AGENTS.md`, `CLAUDE.md`, `README.md`
- [x] `.gitignore`, `LICENSE`, `CHANGELOG.md`

## Planned (not yet in tree)

| Area | Path | Notes |
|------|------|--------|
| Config | `config/`, `categories/` | Templates, `sanitize.json`, tags |
| Docs | `docs/guides/` | Branching, local config, conventions |
| Tooling | `scripts/`, `Makefile` | `unlink-legacy`, import, manifests |
| Claude skills | `ai/claude/skills/` | Import from claude-skills |
| Deploy | `install-system`, `sync-from-system` | Copy-only; no symlinks |
| Cursor | `ai/cursor/rules/` | Thin rules → `AGENTS.md` |
| Hooks | `.pre-commit-config.yaml` | Sanitize, version bump, secrets |

## Runtime today

Until `ai/claude/skills/` and `install-system` exist:

- **Develop skills** in claude-skills
- **Deploy** with `make install` in that repo → `~/.claude/skills/`
- **Private config** at `~/.config/ai-skills/local.json` (Phase 0 migration may already exist on your machine)

## Related work outside this repo

- **Memex** — private comms-write example templates (`ai/claude/skills/comms-write-context/`)
- **claude-skills** — scrub employer-named example filenames before import
- **workstation-devops** — clone path cutover when install moves here
