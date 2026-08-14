---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: vault-entity-integrity-check
description: Scan a vault's entity data (person/org profile files) for missing canonical IDs, likely duplicate entities, and sensitivity-tag scope violations, surfacing findings for review rather than auto-fixing. Use after bulk entity edits, as a periodic vault-hygiene pass, or when asked "check the vault for duplicate entities", "did that migration create any orphan IDs", or "audit entity integrity". Read-only — never edits entity files itself.
compatibility: Works with any vault storing entities as individual profile files (person/org markdown or similar) with frontmatter fields for ID and sensitivity scope.
---

# Vault Entity Integrity Check

Entity data (people, orgs) accumulates integrity problems quietly — a duplicate created by two independent captures of the same person, an ID gap from an interrupted migration, a sensitivity tag that scopes to the wrong level. None of these break anything visibly until someone hits the duplicate or the wrong-scope tag mid-task. This is a read-only audit, not an auto-fixer — findings need a human call on which entity is canonical or which duplicate to merge.

## 1. Missing canonical IDs

Scan every entity file's frontmatter for the canonical-ID field. Flag any entity file that's missing it entirely — a gap most often left by an interrupted or partial migration.

```
MISSING_ID: CRM/People/jane-doe.md
```

## 2. Likely duplicate entities

Flag pairs of entity files whose names are similar (fuzzy match, not just exact) and whose role/context overlaps — the classic "same real person, two files" pattern from independent captures. Don't merge automatically; surface the pair with enough context (both files' key fields) for a human to confirm same-entity vs. genuinely-different-people-same-name.

```
LIKELY_DUPLICATE: CRM/People/jane-doe.md ~ CRM/People/j-doe.md (same role, same org, similar name)
```

## 3. Sensitivity-tag scope violations

For org-type entities, verify the sensitivity/access tag is scoped to the org, not to an individual person — a common mis-tag when an org entity was created by copying a person entity's template. For person-type entities, verify the inverse isn't happening (an org-scoped tag on an individual).

```
SCOPE_VIOLATION: CRM/Orgs/acme-corp.md — tagged person-scope, should be org-scope
```

## 4. Report

Group findings by type, not by file — a reviewer working through duplicates wants all the duplicate pairs together, not interleaved with ID gaps:

```
Vault entity integrity — 3 findings
Missing canonical IDs (1): CRM/People/jane-doe.md
Likely duplicates (1): CRM/People/jane-doe.md ~ CRM/People/j-doe.md
Scope violations (1): CRM/Orgs/acme-corp.md
```

If nothing is found, say so plainly — don't manufacture findings to show the check ran.

## 5. After review

This skill surfaces; it doesn't fix. Once the user confirms what to do with each finding (assign an ID, merge a duplicate, correct a scope tag), make the edit as a normal file change — not as part of this skill's own flow.
