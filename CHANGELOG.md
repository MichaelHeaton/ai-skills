# Changelog

## [Unreleased]

### Added

- `make install-system` / `make sync-from-system` — copy-only deploy `ai/claude/` → `~/.claude/`; whitelist sync back; retired skill cleanup
- `scripts/install-system.sh`, `scripts/sync-from-system.sh`, `scripts/lib/deploy-paths.sh`
- `make install-system-dry-run`, `sync-from-system-apply`; `make install` aliases `install-system`

- `ai/claude/` — 26 skills (retired `uv-weekly` removed), hooks, memory, overlay `CLAUDE.md` imported from claude-skills
- Public scrub — employer names, emails, and hardcoded paths replaced with `local.json` keys and generic labels
- Version frontmatter on all imported `SKILL.md` files (`make bootstrap-version`)
- `.deploy/repo-manifest.json` expanded to 65 paths (`principles/` + `ai/claude/`)
- `docs/guides/memex-and-related-repos.md` — Memex as maintainer PKM name; workstation-devops install path
- `Makefile`, `scripts/` — `unlink-legacy`, `import-from-legacy`, `bootstrap-version`, `manifest-update`
- `.deploy/repo-manifest.json` — MD5 hashes for `principles/` (expands after import)
- `scripts/hooks/legacy-pre-commit` — reference until pre-commit framework lands

## [0.3.0] — 2026-05-27

### Added

- `docs/guides/` — branching, formatting, skill-conventions
- `docs/multi-ai.md`, `docs/README.md`, runbook stubs (`deployment-contexts`, `cross-ai-review`, `self-improvement-loop`, `mcps/`)

## [0.2.0] — 2026-05-27

### Added

- `config/` — `local.template.json`, `accounts.shell.template`, `sanitize.json`, leak-patterns README
- `categories/tags.yaml` — placeholder tag registry
- `docs/guides/local-config.md`

## [0.1.0] — 2026-05-27

### Added

- `principles/` (five files), `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`, MIT `LICENSE`
- `docs/ROADMAP.md` — migration checklist (not duplicated in principles)
