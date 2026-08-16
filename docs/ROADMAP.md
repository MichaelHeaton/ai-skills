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
- [x] `scripts/`, `Makefile` — Phase 0, import, manifest, `install-system`, `sync-from-system`
- [x] `ai/claude/` — skills, hooks, memory, `CLAUDE.md` (import from claude-skills)
- [x] `ai/cursor/rules/` — user rules → `~/.cursor/rules/` via `make install-system`
- [x] `.deploy/repo-manifest.json` — `principles/` + `ai/claude/` + `ai/cursor/rules/`
- [x] `.pre-commit-config.yaml`, `.markdownlint.json`, `.gitleaks.toml`, `.github/workflows/lint.yml` — markdown lint (MD060), YAML, repo-wide secrets scan (gitleaks), SKILL.md PII scan, Tier A version frontmatter; `make lint`, `make hooks-install`

## Planned (not yet in tree)

| Area | Path | Notes |
| ------ | ------ | -------- |
| Docs | stub bodies | Fill deployment-contexts, cross-ai-review, MCP runbooks |
| Deploy | `install-repo`, manifest diff | Per-repo Cursor rules; drift tooling |
| Hooks | pre-commit extras | Sanitize scan; Tier A version check is present |

## Runtime today

- **Source of truth:** `ai/claude/skills/` in this repo
- **Deploy:** `make install-system` → `~/.claude/` and `~/.cursor/rules/` (copy-only). Sync back: `make sync-from-system`
- **Private config:** `~/.config/ai-skills/local.json` (create-if-missing on install)

## Related work outside this repo

- [x] **Memex** — private comms-write examples at `ai/claude/skills/comms-write-context/examples/` ([guide](guides/memex-and-related-repos.md))
- [x] **claude-skills** — public `comms-write` stubs merged
- **workstation-devops** — switch `install_cmd` to `make install-system` in ai-skills (companion MR)
