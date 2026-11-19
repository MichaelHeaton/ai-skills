---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-11-19
updated_by: human
---

# Provenance

Adapted from <https://github.com/mattpocock/skills> on 2026-11-19.

## Kept

The core interview method: interrogate the user relentlessly about a plan or design,
walk the decision tree, ask one question at a time, and offer a recommended answer
with each question.

## Changed

- Rephrased the body to the imperative guidance style used across this repository's
  skills, and framed the "explore the codebase instead of asking" rule as a
  standing behavior rather than a closing aside.
- Dropped the upstream title heading from the body so the skill reads as direct
  operating guidance.

## Why

The skill was adopted to match this repository's authoring conventions while
preserving the upstream method. Changes are editorial, not behavioral.

## Relationship to upstream

As of 2026-11-19, upstream `skills/productivity/grill-me/SKILL.md` is a thin wrapper
that delegates to a separate `grilling` skill, which runs the interview in rounds over
a design tree and dispatches sub-agents to look up facts. This copy still uses the
earlier single-question-at-a-time approach, so it is a deliberate divergence from the
current upstream rather than a match to it. Re-check upstream `grill-me` and
`grilling` before pulling changes; if the frontier-and-rounds approach is preferable,
adopt it deliberately and update `metadata.adapted_ref` in `SKILL.md`.
