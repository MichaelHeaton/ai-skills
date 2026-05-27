---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Skill conventions

## Naming

- **Format**: `{domain}-{verb}` for action skills, `{domain}-{noun}` for support/tool skills
- **Case**: lowercase letters and hyphens only — no uppercase, underscores, or spaces
- **Length**: 1–64 characters
- **Rules**: no leading, trailing, or consecutive hyphens
- The `name` field in `SKILL.md` frontmatter must exactly match the directory name

**Examples**

| Pattern | Examples |
|---|---|
| `{domain}-{verb}` | `issue-create`, `issue-list`, `skill-create` |
| `{domain}-{noun}` | `vault-support`, `pr-slack` |
| Intentional exceptions | `grill-me` (conversational, self-referential) |

## Domain prefixes

| Domain | Prefix | Notes |
|---|---|---|
| HashiCorp Vault (work) | `vault-` | Vault-specific skills |
| Work org (broader employer scope) | `ces-`, `adobe-` | Team-specific; pick what matches your org |
| Client / contract work | `uv-` | Example: dedicated client account |
| Personal knowledge base | `memex-` | Historical prefix for PKM capture skills (name kept for compatibility) |
| GitHub-specific | `gh-` | Platform-only helpers |
| GitLab-specific | `gl-` | Platform-only helpers |
| Cross-platform VCS | `issue-`, `pr-`, `git-` | GitHub and GitLab — no platform prefix |
| Skill management | `skill-` | Creating, reviewing, managing skills |

## Directory layout

**Target (this repo):**

```
ai/claude/skills/
└── skill-name/
    ├── SKILL.md          # Required
    ├── scripts/          # Executable code the skill runs
    ├── references/       # Docs loaded into context as needed
    └── assets/           # Templates, icons, static files
```

**Legacy runtime (until import):** same structure under `claude-skills/skills/`.

Only create `scripts/`, `references/`, or `assets/` when the skill actually needs them.

## SKILL.md structure

```markdown
---
name: skill-name
description: One-paragraph description of what the skill does and *when* to use it.
  Include specific trigger phrases and contexts. Be slightly pushy — agents undertrigger
  skills, so lean toward listing more situations where the skill applies.
compatibility: Required tools or environment, if any. Omit if not needed.
---

# Skill Title

Brief orientation paragraph.

## Section 1

...
```

### Frontmatter fields

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Must match directory name |
| `description` | Yes | Max 1024 chars. What it does + when to trigger. |
| `compatibility` | No | List tool/env requirements (git, Python, etc.) |
| `license` | No | For skills shared publicly |
| `metadata` | No | Arbitrary key-value pairs |
| `allowed-tools` | No | Space-separated pre-approved tools (experimental) |

### Description guidelines

- Lead with what the skill does, follow with when to trigger
- Include specific user phrases that should activate the skill
- Reference related skills by name if there is overlap
- Keep it under 1024 characters

### Body guidelines

- Keep `SKILL.md` ≤200 lines ([principles/versioning.md](../../principles/versioning.md))
- Move detail into `references/` (up to ~500 lines per file) and link from `SKILL.md`
- Write instructions in imperative form ("Do X", not "You should do X")
- Explain *why* behind non-obvious steps
- No comments in code blocks that only restate the code

## Git operations

Commits, pushes, and PRs/MRs follow the **`git-ops`** skill. Branching by repo type: [branching.md](branching.md).

## Workflow for adding a new skill

1. Run **`skill-create`** (guided interview)
2. Add the skill under `ai/claude/skills/<name>/` in this repo (or `claude-skills/skills/` until import lands)
3. Deploy with `make install-system` (target) or `make install` in claude-skills (today)
4. Branch + PR in the skills repo; merge to main before relying on it on other machines
5. On other machines: pull and re-run install
