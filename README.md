# ai-skills

A **portable multi-AI workspace** — versioned skills, principles, and conventions for [Claude Code](https://claude.com/claude-code), [Cursor](https://cursor.com), and other agents that read [AGENTS.md](https://agents.md).

Imported from [claude-skills](https://github.com/MichaelHeaton/claude-skills) (legacy repo to be archived after cutover).

> **AI agents:** read [AGENTS.md](AGENTS.md) first. Principles: [principles/](principles/).

---

## Status

| Milestone | State |
|-----------|--------|
| Phase 0 — unlink symlinks | Done (`make unlink-legacy`) |
| PR 1 — greenfield scaffold | This branch |
| PR 2 — `install-system` + sync-back | Planned |
| Cursor rules | PR 4 |

---

## Clone and setup

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
cd ai-skills

# First-time import from legacy repo (maintainers)
make import-legacy
make bootstrap-version
make manifest-update

# Phase 0 on machines that used symlink install
make unlink-legacy
```

Private config: **`~/.config/ai-skills/local.json`** (from `config/local.template.json`). Never commit filled copies.

---

## Makefile targets

| Target | Purpose |
|--------|---------|
| `make import-legacy` | Copy content from `../claude-skills` into target layout |
| `make bootstrap-version` | Add version frontmatter to skills |
| `make manifest-update` | Regenerate `.deploy/repo-manifest.json` |
| `make unlink-legacy` | Phase 0: materialize `~/.claude` copies, migrate config |

---

## Layout

```
principles/           # Universal rules (all AIs)
ai/claude/skills/     # Claude Code skills
ai/claude/hooks/      # Claude hooks
docs/guides/          # Branching, local config, conventions
categories/tags.yaml  # Placeholder definitions
config/               # Public templates + sanitize rules
.deploy/              # MD5 deploy manifests
```

---

## Skills

| Skill | What it does |
|-------|----------------|
| `comms-write` | Draft emails, Slack messages, announcements |
| `decision-council` | Five-advisor decision process with peer review |
| `doc-coauthor` | Co-write technical documentation |
| `git-ops` | Git hygiene — commits, PRs, pre-commit |
| `grill-me` | Stress-test a plan via interview |
| `iac-triage` | Infrastructure / Terraform triage |
| `issue-create` | Create GitHub, GitLab, or Jira issues |
| `issue-focus` | Focus session on one issue |
| `issue-get` | Fetch ticket details by ID |
| `issue-list` | List and triage open issues |
| `issue-update` | Update issue status or comments |
| `lean-context` | Context discipline reminders |
| `log-clip` | Filter and clip logs (`clog`) |
| `memex-decide` | Log decisions to Memex wiki |
| `memex-dump` | Fast brain dump to issue queue |
| `model-route` | Route tasks to appropriate models |
| `pr-slack` | Slack message for PR review |
| `repo-ai-init` | Bootstrap AGENTS.md for a repo |
| `repo-setup` | Standard repo tooling setup |
| `session-close` | End-of-session hygiene |
| `skill-create` | Build a skill via guided interview |
| `skill-review` | Audit existing skills |
| `skill-session-handoff` | Cross-session context handoff |
| `vault-support` | Vault support thread analysis |
| `weekly-report` | UV / work weekly report outputs |
| `youtube-watch` | Track YouTube videos to watch |

---

## License

See [LICENSE](LICENSE).
