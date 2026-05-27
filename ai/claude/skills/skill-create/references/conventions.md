# Skill Conventions

## Naming

- **Format**: `{domain}-{verb}` for action skills, `{domain}-{noun}` for support/tool skills
- **Case**: lowercase letters and hyphens only — no uppercase, underscores, or spaces
- **Length**: 1–64 characters
- **Rules**: no leading, trailing, or consecutive hyphens
- The `name` field in `SKILL.md` frontmatter must exactly match the directory name

**Examples**

| Pattern | Examples |
|---|---|
| `{domain}-{verb}` | `issue-create`, `issue-list`, `pr-review`, `skill-create` |
| `{domain}-{noun}` | `vault-support`, `pr-slack` |
| Intentional exceptions | `grill-me` (conversational, self-referential) |

## Domain prefixes

| Domain | Prefix | Notes |
|---|---|---|
| HashiCorp Vault Admin (Adobe/CES) | `vault-` | Vault-specific skills |
| CES org (broader Adobe work) | `ces-` | Non-vault Adobe/CES tasks |
| Adobe company-wide | `adobe-` | Cross-org Adobe work |
| Ultraviolet Cyber | `uv-` | UV-specific work |
| Memex (2nd brain) | `memex-` | Personal knowledge system |
| GitHub (Adobe + personal) | `gh-` | GitHub-specific only |
| GitLab (personal) | `gl-` | GitLab-specific only |
| Cross-platform VCS | `issue-`, `pr-` | Works across GitHub and GitLab — no platform prefix |
| Skill management | `skill-` | Creating, reviewing, managing skills |

## Directory layout

```
skills/
└── skill-name/
    ├── SKILL.md          # Required
    ├── scripts/          # Executable code the skill runs
    ├── references/       # Docs loaded into context as needed
    └── assets/           # Templates, icons, static files
```

Only create `scripts/`, `references/`, or `assets/` when the skill actually needs them.

## SKILL.md structure

```markdown
---
name: skill-name
description: One-paragraph description of what the skill does and *when* to use it.
  Include specific trigger phrases and contexts. Be slightly pushy — Claude undertriggers
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
- Reference related skills by name if there's overlap
- Keep it under 1024 characters

### Body guidelines

- Keep `SKILL.md` under 500 lines
- If approaching that limit, move detail into `references/` files and link to them
- Write instructions in imperative form ("Do X", not "You should do X")
- Explain *why* behind non-obvious steps rather than just what to do
- No comments in code blocks that just restate what the code does

## Git operations

All git commits, pushes, and PRs/MRs follow the rules in the `git-ops` skill — commit message format, PR description format, pre-commit checks (including scoped `terraform fmt`), and scope discipline. See `skills/git-ops/SKILL.md`.

Branching rules by repo type are in `references/branching.md`.

---

## Workflow for adding a new skill

1. Run `/skill-create` — the guided interview will draft the skill
2. The skill is created in the skills repo; the symlink at `~/.claude/skills/` makes it live immediately
3. The symlink in `~/.claude/skills/` makes it live immediately
4. `git commit && git push` to sync to other workstations
5. On other workstations, `git pull` picks up the new skill automatically
