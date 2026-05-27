# ai-skills

Public, versioned **multi-AI workspace** for assistant skills, principles, and conventions.

> **AI agents:** read [AGENTS.md](AGENTS.md) first, then [principles/](principles/).

## Status

The repository is **under construction**. Present: `principles/`, `config/` templates, `categories/tags.yaml`, entry docs. Skills and install tooling are not here yet — see [docs/ROADMAP.md](docs/ROADMAP.md).

Private values: copy [`config/local.template.json`](config/local.template.json) to `~/.config/ai-skills/local.json` ([guide](docs/guides/local-config.md)).

## Skills today

**Runtime skills** still come from [claude-skills](https://github.com/MichaelHeaton/claude-skills):

```bash
cd ~/Projects/personal/claude-skills && make install
```

After `ai/claude/skills/` exists in this repo, deployment will move to `make install-system` here (documented in [principles/deployment.md](principles/deployment.md)).

## Clone

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
```

## License

[MIT](LICENSE)
