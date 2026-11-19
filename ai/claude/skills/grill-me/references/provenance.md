---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-11-19
updated_by: human
---

# Provenance

Adapted on 2026-11-19 from the author's work:

- **Source repository** — <https://github.com/mattpocock/skills>
- **Author's documentation** — <https://www.aihero.dev/skills-grill-me>

`metadata.adapted_from` names the repository because that is the file source a later
review diffs; the documentation page explains intended behavior.

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

As of 2026-11-19, upstream `grill-me` is a thin, user-invoked wrapper that delegates to
a separate `grilling` skill, which runs the interview in rounds over a design tree and
dispatches sub-agents to look up facts. The one-question-at-a-time style this copy uses
is not obsolete upstream: the author's documentation lists it as a supported option
(set by adding "When grilling, ask one question at a time" to the agent's global
instructions). So this is a deliberate choice among upstream-sanctioned styles. Re-read
the documentation and diff against upstream `grill-me` and `grilling` before pulling
changes; if the rounds-and-frontier default is preferable, adopt it deliberately and
add `adapted_ref` to `SKILL.md`.
