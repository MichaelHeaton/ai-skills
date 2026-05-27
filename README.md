# ai-skills

Public, versioned **multi-AI workspace** for assistant skills, principles, and conventions.

> **AI agents:** read [AGENTS.md](AGENTS.md) first, then [principles/](principles/).

## Status

The repository is **under construction**. Present: `principles/`, `config/` templates, `categories/tags.yaml`, [docs/](docs/README.md), `Makefile` + `scripts/`, and **`ai/claude/`** (27 skills + hooks + memory). Deploy from this repo lands in a follow-up (`install-system`) — see [docs/ROADMAP.md](docs/ROADMAP.md).

```bash
make help                  # scripts overview
make unlink-legacy-dry-run # preview Phase 0 (if still on symlinks)
```

Private values: copy [`config/local.template.json`](config/local.template.json) to `~/.config/ai-skills/local.json` ([guide](docs/guides/local-config.md)).

**[Memex](https://github.com/MichaelHeaton/memex)** is the maintainer’s personal second-brain vault — a project name, not something every user must run. See [docs/guides/memex-and-related-repos.md](docs/guides/memex-and-related-repos.md).

## Install (author’s workstations)

Use **[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops)** (`make apply`) to clone this repo, memex, and claude-skills and run skill install. Manual fallback: `make install` in claude-skills until `make install-system` exists here.

## Skills today

**Runtime skills** still come from [claude-skills](https://github.com/MichaelHeaton/claude-skills):

```bash
cd ~/Projects/personal/claude-skills && make install
```

Skill bodies live in `ai/claude/skills/`. Deployment will move to `make install-system` here (documented in [principles/deployment.md](principles/deployment.md)).

## Clone

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
```

## License

[MIT](LICENSE)
