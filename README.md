# ai-skills

Public, versioned **multi-AI workspace** for assistant skills, principles, and conventions.

> **AI agents:** read [AGENTS.md](AGENTS.md) first, then [principles/](principles/).

## Status

This repository is under **incremental construction**. [PR #1](https://github.com/MichaelHeaton/ai-skills/pull/1) was superseded by smaller reviews starting with **PR-A** (core skeleton only).

| PR | Focus |
|----|--------|
| **A** | Principles + `AGENTS.md` (you are here) |
| B | Config templates, tags, sanitize rules |
| C | Documentation guides |
| D | Phase 0 / import scripts (no skill import yet) |
| E | Comms-write scrub (claude-skills + Memex) |
| F | Import `ai/claude/skills/` (26 skills) |
| G | Copy-only `install-system` + sync-back |

## Skills today

**Runtime skills** still come from [claude-skills](https://github.com/MichaelHeaton/claude-skills) until PR-F and PR-G land.

```bash
# Existing workflow (unchanged for now)
cd ~/Projects/personal/claude-skills && make install
```

## Clone

```bash
git clone git@github.com-personal:MichaelHeaton/ai-skills.git \
  ~/Projects/personal/ai-skills
```

## License

[MIT](LICENSE)
