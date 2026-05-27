# ai-skills

Public, versioned **multi-AI workspace** for assistant skills, principles, and conventions.

> **AI agents:** read [AGENTS.md](AGENTS.md) first, then [principles/](principles/).

## Status

The repository is **under construction**. This branch has the core skeleton (`principles/`, entry docs). Skills, config templates, and install tooling are not here yet — see [docs/ROADMAP.md](docs/ROADMAP.md).

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
