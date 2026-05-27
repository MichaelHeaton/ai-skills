# Changelog

All notable changes to [ai-skills](https://github.com/MichaelHeaton/ai-skills) are documented here.

## [Unreleased]

### Added

- Greenfield repo layout: `principles/`, `ai/claude/`, `docs/`, `categories/`, `config/`
- Import from legacy `claude-skills` via `make import-legacy`
- Phase 0 `make unlink-legacy` (materialize copies, migrate `~/.config/ai-skills`)
- Tier A version frontmatter on skills via `make bootstrap-version`
- `.deploy/repo-manifest.json` MD5 fingerprints via `make manifest-update`
