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
- [x] `config/` — templates, `sanitize.json`, leak-patterns README
- [x] `categories/tags.yaml` — placeholder tag registry
- [x] `docs/guides/` — local-config, branching, formatting, skill-conventions
- [x] `docs/multi-ai.md`, `docs/README.md`
- [x] Doc stubs — deployment-contexts, cross-ai-review, self-improvement-loop, `mcps/`
- [x] `scripts/`, `Makefile` — Phase 0, import, manifest
- [x] `ai/claude/` — skills, hooks, memory, `CLAUDE.md` (import from claude-skills)
- [x] `.deploy/repo-manifest.json` — `principles/` + `ai/claude/` (65 paths)

## Planned (not yet in tree)

| Area | Path | Notes |
|------|------|--------|
| Docs | stub bodies | Fill deployment-contexts, cross-ai-review, MCP runbooks |
| Deploy | `install-system`, `sync-from-system` | Copy-only; no symlinks |
| Cursor | `ai/cursor/rules/` | Thin rules → `AGENTS.md` |
| Hooks | `.pre-commit-config.yaml` | Sanitize, version bump, secrets |

## Runtime today

Until `install-system` exists:

- **Source of truth** for skill bodies: `ai/claude/skills/` in this repo
- **Deploy** still uses `make install` in claude-skills → `~/.claude/skills/` (or edit here and re-import until cutover)
- **Private config** at `~/.config/ai-skills/local.json` (Phase 0 migration may already exist on your machine)

## Related work outside this repo

- [x] **Memex** — private comms-write examples at `ai/claude/skills/comms-write-context/examples/` ([guide](guides/memex-and-related-repos.md))
- [x] **claude-skills** — public `comms-write` stubs merged
- **workstation-devops** — clones all three repos; runs `make install` in claude-skills until `install-system` here
