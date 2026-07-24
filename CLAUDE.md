# CLAUDE.md — ai-skills

> Claude Code overlay. Universal context: [AGENTS.md](AGENTS.md). Principles: [principles/](principles/).

## Branch and PR rules

**Never push directly to `main`.** All changes go through a pull request.

- Branch: `feat/...`, `fix/...`, or `chore/...`
- Open PR with `gh pr create` — do not merge; owner reviews
- No force-push without explicit instruction

**When the user says a PR merged**, do this automatically without being asked each time:

1. Pull `main` (fast-forward) in the primary checkout
2. Remove the worktree and delete the local feature branch (skip remote branch deletion if GitHub already auto-deleted it)
3. Run `make install-system` to redeploy

## Content caution

Public repo. No employer names, Jira keys, or internal URLs in commits. Placeholder definitions: [categories/tags.yaml](categories/tags.yaml).

## Skills (current)

Skill bodies: `ai/claude/skills/`. Deploy: `make install-system` (copy-only). Conventions: [docs/guides/skill-conventions.md](docs/guides/skill-conventions.md). Multi-AI layout: [docs/multi-ai.md](docs/multi-ai.md).

## Private config

`~/.config/ai-skills/local.json` on your machine — copy from [config/local.template.json](config/local.template.json). See [docs/guides/local-config.md](docs/guides/local-config.md).
