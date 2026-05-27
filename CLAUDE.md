# CLAUDE.md — ai-skills

> Claude Code overlay. Universal context: [AGENTS.md](AGENTS.md). Principles: [principles/](principles/).
> Private config: `~/.config/ai-skills/local.json` (see [docs/guides/local-config.md](docs/guides/local-config.md)).

## Branch and PR rules

**Never push directly to `main`.** All changes go through a pull request.

- Branch: `feat/...`, `fix/...`, or `chore/...`
- `gh pr create` — do not merge; owner reviews
- No force-push without explicit instruction

## Content caution

Public repo. Scrub employer names, Jira keys, and internal URLs before commit. Use placeholders from [categories/tags.yaml](categories/tags.yaml).

## Skill locations

Skills live only under **`ai/claude/skills/<name>/SKILL.md`**.

## Global formatting

Installed copy of formatting rules: [ai/claude/CLAUDE.md](ai/claude/CLAUDE.md) (deployed to `~/.claude/CLAUDE.md` via `make install-system` in PR 2).
