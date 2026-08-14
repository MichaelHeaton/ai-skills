---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: vault-phased-migration-tracker
description: Track a multi-phase vault (personal knowledge base) migration's rules and invariants across several sequential PRs or sessions, and re-verify earlier phases haven't regressed when later phases land. Use when a vault-schema or data migration is declared to span multiple phases (e.g. canonical entity IDs, then org-hierarchy rebuild, then a sensitivity-tag scheme change), or when asked "did the earlier phase's rule still hold after this change", "what's the status of the migration phases", or "check the migration checklist".
compatibility: Works with any vault/PKM repo structured as sequential PRs against one migration.
---

# Vault Phased Migration Tracker

A multi-phase migration's rules are easy to state once and easy to silently break later — a later phase's fix can violate an earlier phase's invariant without anyone noticing, because nothing re-checks phase 1 once phase 3 starts.

## 1. Declare the migration

At the start of a multi-phase migration, capture:

- **Phases**, in order, each with a one-line description
- **Invariants per phase** — the specific rule that phase establishes and that later phases must not violate (e.g. "every entity has exactly one canonical ID", "every org-type entity's sensitivity tag scopes to the org, not an individual")
- **Status per phase**: not started / in progress / landed (with PR/commit reference)

Keep this as a short checklist, either in a tracking issue or a scratch note — not spread across each phase's own PR description where it can't be seen as a whole.

## 2. Before landing a new phase

Before merging a PR for phase N, check that its changes don't violate any invariant already established by phases 1 through N-1. This is a targeted check against the specific invariants list, not a full re-audit of the vault — grep or query for the specific pattern each earlier invariant claims (e.g. "every org entity has a `scope: org` tag" → query for org-type entities missing that tag).

## 3. After landing a new phase

Re-verify the invariants of **all already-landed phases**, not just the one that just landed — a phase N change can have side effects on phase 1's data that phase N's own review didn't think to check. Use `vault-entity-integrity-check` _(global: ai-skills)_ if the invariant is entity-shape related (duplicate IDs, missing canonical IDs, sensitivity-tag scope).

## 4. Report the checklist

```
Migration: Canonical Entity ID Rollout
✓ Phase 1 — canonical IDs assigned (PR #142) — invariant holds
✓ Phase 2 — org-hierarchy rebuild (PR #150) — invariant holds, phase 1 re-verified clean
⏳ Phase 3 — sensitivity-tag scheme change — not started
```

Surface this on request, or proactively when a new phase's PR is about to land, so the person merging sees the full picture rather than just the diff in front of them.
