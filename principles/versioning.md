---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: human
---

# Versioning principles

## Metadata (required on versioned files)

```yaml
version: MAJOR.MINOR.PATCH
principles_version: MAJOR.MINOR.PATCH
last_updated: YYYY-MM-DD
updated_by: claude | cursor | human
```

### Cursor rules (`.mdc`)

Files under `ai/cursor/rules/` use **one** YAML frontmatter block: repo version fields **first**, then Cursor-native fields:

```yaml
---
version: 1.0.0
principles_version: 1.0.0
last_updated: YYYY-MM-DD
updated_by: human
description: Short label for the rule picker (Cursor)
alwaysApply: true   # or globs: [...] when not global
---
```

Do not omit `description` / `alwaysApply` / `globs` — Cursor needs them. Run `make bootstrap-version` to normalize order and fill missing version keys.

## Semver for skills and rules

| Bump | When |
| ------ | ------ |
| **MAJOR** | Breaking change to skill logic or interface |
| **MINOR** | New capability; backwards compatible |
| **PATCH** | Wording, bug fix, clarification |

When you edit a versioned file, bump the appropriate component and update `last_updated` / `updated_by`.

## Tiers

| Tier | Paths | Enforcement |
| ------ | ------- | ------------- |
| **A** | `ai/**/SKILL.md`, `ai/cursor/rules/**`, `principles/**` | Required once paths exist |
| **B** | `docs/**`, `scripts/**`, `ai/claude/skills/**/references/*.md`, `ai/claude/skills/**/examples/*.md` | Recommended (version block via `make bootstrap-version`) |
| **C** | Templates, `CHANGELOG.md` | Optional |

## Size limits (skills)

- **SKILL.md** and **`.mdc` rules**: target ≤200 lines
- **Skill `references/`**: up to ~500 lines per file
