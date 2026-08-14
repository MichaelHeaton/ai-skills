---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Skill conventions

Skills must be **domain-aware** — portable in git, proprietary only in private answer files. Read [principles/domains.md](../../principles/domains.md) before authoring or reviewing a skill.

## Naming

- **Format**: `{domain}-{verb}` for action skills, `{domain}-{noun}` for support/tool skills
- **Case**: lowercase letters and hyphens only — no uppercase, underscores, or spaces
- **Length**: 1–64 characters
- **Rules**: no leading, trailing, or consecutive hyphens
- The `name` field in `SKILL.md` frontmatter must exactly match the directory name

**Examples**

| Pattern | Examples |
| --- | --- |
| `{domain}-{verb}` | `issue-create`, `issue-list`, `skill-create` |
| `{domain}-{noun}` | `weekly-report`, `repo-setup` |
| No domain prefix | `git-ops`, `grill-me` (cross-cutting or conversational) |

## Domain prefixes (optional)

**Default: no prefix** when the skill works across employers, clients, and tools. Prefer `issue-create`, `git-ops`, `skill-review` over baking org names into public skill names.

Add a short `{context}-` prefix only when the skill is useless outside one scope (a specific product, employer team, client account, or personal PKM repo). Pick a slug you control; keep it stable. **Do not maintain a master prefix table in this public repo** — that list is personal/team metadata and belongs in private notes, `~/.config/ai-skills/local.json` comments, or your org’s internal docs. **In public examples**, use fictional slugs from [categories/tags.yaml](../../categories/tags.yaml) (e.g. `acme`, not a real client name).

| Situation | Guidance |
| --- | --- |
| GitHub + GitLab issues/PRs | `issue-`, `pr-`, `git-` — no platform prefix unless the skill is platform-only |
| Platform-only helper | `gh-` or `gl-` only when the other platform cannot run it |
| One product or program | Product or program slug, e.g. `terraform-`, `k8s-` — not employer name |
| Legacy imports | Older skills may keep historical prefixes; rename when you touch them |
| PR + Slack | Use **`comms-write`** with `work-primary-pr-review` example — not `{channel}` in the skill name (e.g. avoid `pr-slack`) |

Use **`skill-create`** when adding a skill — it walks through naming without requiring a global prefix registry.

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

**`references/` and `examples/`** markdown files use the same **version block** as `principles/` (four fields at the top — no `name` / `description`). Run `make bootstrap-version` after adding or editing them.

## SKILL.md structure

```markdown
---
version: 1.0.0
principles_version: 1.0.0
last_updated: YYYY-MM-DD
updated_by: human
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
| --- | --- | --- |
| `version` | Yes | Semver for this skill ([principles/versioning.md](../../principles/versioning.md)) |
| `principles_version` | Yes | `principles/` version the skill was written against |
| `last_updated` | Yes | `YYYY-MM-DD` |
| `updated_by` | Yes | `human`, `claude`, or `cursor` |
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

### Environment compatibility (local-only vs. cloud-compatible)

"The skill exists in the repo" and "the skill will actually work in this session" are different facts once a cloud/web session (`claude.ai/code`) enters the picture — some skills assume local-machine state (`~/.config/ai-skills/local.json`, a local git clone at a hardcoded path, workstation-only tooling like `make install-system` or `launchd`) that a cloud container never has, no matter how current the deployed skill file is.

Reuse the existing `compatibility` field for this rather than adding a new one:

- **Local-machine-only skill**: lead the field with `Local machine only —` followed by what specifically breaks in a cloud session (a hardcoded path, a workstation CLI, an OS-specific mechanism), so a session can recognize the gap immediately instead of trying and hitting an error. Name a fallback if one exists.
- **Cloud-compatible skill with tool dependencies**: state the tool/env requirements as before (`Requires gh CLI, git`) — these gate on tool *presence*, checkable and often satisfiable in either environment, not on local-machine-only assumptions.
- **Explicitly cloud-compatible skill**: for a skill whose portability might otherwise be assumed to require a workstation (e.g. it neighbors local-only skills, or its name suggests deploy/install machinery), a short affirmative note (`Cloud-compatible — no local-machine-only paths or tooling`) is worth the one line, same as `post-merge-cleanup` does.

**Fast-fail vs. soft warning** — default to a fast-fail with a clear message when a missing local dependency would otherwise make the skill do something silently wrong or partial (e.g. `issue-create`'s `append-task-index.sh` skipping cleanly with a warning rather than crashing). Use a soft warning only when the skill can still do most of its job usefully without the local piece.

This declares a skill's own content assumptions — it does not by itself confirm the skill is *deployed* in the current session. See `CLAUDE.md`'s auto-invoke wording for the deployment-gap fallback (read the SKILL.md directly from a repo checkout when the `Skill` tool reports "Unknown skill").

## Attribution (adapting external skills)

When a skill, subagent, hook, or MCP config is adapted from something external — a public repo, marketplace listing, gist, or blog post the user pointed at — record where it came from so a later review can check whether the original moved on.

- Add `metadata: {adapted_from: <url>}` to frontmatter — the existing free-form `metadata` field already supports this, no schema change needed
- If the adaptation is substantial (rewritten body, different mechanism, merged with an existing convention), add a short note in the body or a `references/provenance.md` covering what was kept vs. changed and why
- If the source has a license that requires credit, also set the `license` field
- `skill-review`'s periodic tune-up checks any skill with `metadata.adapted_from` set and offers to diff against upstream

This isn't optional bookkeeping — it's the difference between "we made our own version" and "we forked and lost the map back."

## Git operations

Commits, pushes, and PRs/MRs follow the **`git-ops`** skill. Branching by repo type: [branching.md](branching.md).

## Workflow for adding a new skill

1. Run **`skill-create`** (guided interview)
2. Add the skill under `ai/claude/skills/<name>/` in this repo
3. Deploy with `make install-system` (see [ROADMAP.md](../ROADMAP.md) if not merged yet)
4. Branch + PR in the skills repo; merge to main before relying on it on other machines
5. On other machines: pull and re-run install
