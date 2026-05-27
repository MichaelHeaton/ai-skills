---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Versioning principles

## Metadata (required on Tier A files)

```yaml
version: MAJOR.MINOR.PATCH
principles_version: MAJOR.MINOR.PATCH
last_updated: YYYY-MM-DD
updated_by: claude | cursor | human
```

## Semver for skills and rules

| Bump | When |
|------|------|
| **MAJOR** | Breaking change to skill logic or interface |
| **MINOR** | New capability; backwards compatible |
| **PATCH** | Wording, bug fix, clarification |

When editing a file, bump the appropriate component and set `last_updated` / `updated_by`.

## Principles drift

`principles_version` on a skill should match the current version in this file (or higher). `make sync-principles` (PR 5) flags drift.

## Tiers

| Tier | Paths | Enforcement |
|------|-------|-------------|
| **A** | `ai/claude/skills/**/SKILL.md`, `ai/cursor/rules/**`, `principles/**` | Required; bump on change (PR 3+) |
| **B** | `docs/**`, `scripts/**` | Recommended |
| **C** | Templates, `CHANGELOG.md`, `categories/*` | Optional |

## Size limits

- **SKILL.md** and **`.mdc` rules**: target ≤200 lines; extract to `references/` inside the skill
- **Skill `references/`**: up to ~500 lines per file
