# ai-skills

Public, versioned **multi-AI workspace** for assistant skills, principles, and conventions.

> **AI agents:** read [AGENTS.md](AGENTS.md) first, then [principles/](principles/).

## Status

Present: `principles/`, `config/` templates, `categories/tags.yaml`, [docs/](docs/README.md), `Makefile` + `scripts/`, and **`ai/claude/`** (28 skills + hooks + memory). Deploy: **`make install-system`** (copy-only).

```bash
make help                      # scripts overview
make install-system-dry-run    # preview deploy → ~/.claude/
make install-system            # deploy ai/claude/ → ~/.claude/
make sync-from-system          # dry-run: pull ~/.claude/ edits into repo
make lint                      # run markdown/YAML/secrets checks manually
```

Git hooks (`make hooks-install`) run automatically via **workstation-devops** `make apply`. Manual install: `brew install pre-commit && make hooks-install`.

Private values: copy [`config/local.template.json`](config/local.template.json) to `~/.config/ai-skills/local.json` ([guide](docs/guides/local-config.md)).

**[Memex](https://github.com/MichaelHeaton/memex)** is the maintainer’s personal second-brain vault — a project name, not something every user must run. See [docs/guides/memex-and-related-repos.md](docs/guides/memex-and-related-repos.md).

## Install (author’s workstations)

Use **[workstation-devops](https://gitlab.com/Michael-Heaton/workstation-devops)** (`make apply`) to clone this repo, run **`make install-system`**, and install git hooks via **`make hooks-install`**. `pre-commit` comes from Homebrew on playbook-managed Macs.

Manual (no playbook):

```bash
cd ~/Projects/personal/ai-skills
make install-system
brew install pre-commit   # or pipx install pre-commit
make hooks-install
```

Skill bodies: `ai/claude/skills/`. See [principles/deployment.md](principles/deployment.md). [claude-skills](https://github.com/MichaelHeaton/claude-skills) remains for archive/redirect only after cutover.

## Clone

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
```

## License

[MIT](LICENSE)
