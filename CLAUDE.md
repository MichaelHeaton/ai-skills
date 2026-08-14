# CLAUDE.md — ai-skills

> Claude Code overlay. Universal context: [AGENTS.md](AGENTS.md). Principles: [principles/](principles/).

## Branch and PR rules

**Never push directly to `main`.** All changes go through a pull request.

- Branch: `feat/...`, `fix/...`, or `chore/...`
- Open PR with `gh pr create` — do not merge; owner reviews
- No force-push without explicit instruction

**When the user says a PR merged**, run the `post-merge-cleanup` skill _(global: ai-skills)_ automatically without being asked each time — it covers the pull/worktree/branch-delete sequence and redeploys via `make install-system` (this repo's redeploy step).

**Cloud sessions**: a skill just merged to `main` isn't necessarily available yet — cloud containers never run `make install-system`, so "the skill exists in the repo" and "the skill is available in this session" are different facts. If an auto-invoke directive like this one names a skill the `Skill` tool reports as unknown, treat that as an expected environment gap, not an error to route around silently: read the skill's SKILL.md directly from the repo checkout and follow its steps manually instead of skipping the directive or improvising from memory.

## Content caution

Public repo. No employer names, Jira keys, or internal URLs in commits. Placeholder definitions: [categories/tags.yaml](categories/tags.yaml).

## Skills (current)

Skill bodies: `ai/claude/skills/`. Deploy: `make install-system` (copy-only). Conventions: [docs/guides/skill-conventions.md](docs/guides/skill-conventions.md). Multi-AI layout: [docs/multi-ai.md](docs/multi-ai.md).

## Private config

`~/.config/ai-skills/local.json` on your machine — copy from [config/local.template.json](config/local.template.json). See [docs/guides/local-config.md](docs/guides/local-config.md).
