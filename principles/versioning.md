---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-05-27
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

## Semver for skills and rules

| Bump | When |
|------|------|
| **MAJOR** | Breaking change to skill logic or interface |
| **MINOR** | New capability; backwards compatible |
| **PATCH** | Wording, bug fix, clarification |

When you edit a versioned file, bump the appropriate component and update `last_updated` / `updated_by`.

## Tiers

| Tier | Paths | Enforcement |
|------|-------|-------------|
| **A** | `ai/**/SKILL.md`, `ai/cursor/rules/**`, `principles/**` | Required once paths exist |
| **B** | `docs/**`, `scripts/**` | Recommended |
| **C** | Templates, `CHANGELOG.md` | Optional |

## Size limits (skills)

- **SKILL.md** and **`.mdc` rules**: target ≤200 lines
- **Skill `references/`**: up to ~500 lines per file
