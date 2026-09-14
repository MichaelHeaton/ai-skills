---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: skill-corpus-sweep
description: Sweep the entire skill corpus (ai/claude/skills/ and related doc trees like docs/guides/) for every reference to a named external system or routing destination when it is being added, renamed, or removed — survey broadly, classify each hit as live routing logic vs. doc mention vs. historical/changelog note, plan the edit per hit, apply per-file, then grep-verify zero remaining live references as a final gate, and produce an auditable change summary. Use for "remove X as a routing destination", "rename references to X across skills", "sweep the skill corpus for Y", "decommission this integration everywhere", or any multi-file mechanical update where a missed reference would silently keep routing to a dead or renamed system. Formalizes the manual sequence run in ai-skills#409 (Linear routing removal). Not for adding new functionality to a single skill (use skill-create) or a one-off single-file edit.
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Requires git and grep.
---

# Skill Corpus Sweep

A repeatable checklist for changing how the skill corpus refers to one named external system or routing destination — adding it, renaming it, or removing it — without leaving a stray reference that silently misroutes later. This formalizes the manual sequence run in `ai-skills#409` (Linear routing removal): survey, classify, plan, edit, verify, report.

The risk this guards against: a missed reference doesn't error loudly. It just sits there and keeps pointing at a system that no longer exists (or exists under a new name), and nobody notices until something routes wrong.

## 1. Survey broadly

Search the whole corpus for every reference to the target system — not just `ai/claude/skills/`, but any doc tree that might mention routing (`docs/guides/`, `principles/`, `AGENTS.md`, etc.).

A single `grep` pattern is not enough — it misses variant spellings, casing, abbreviations, and indirect references (a skill that says "the ticketing tool" without naming it, or references a URL/domain instead of the product name). Run several passes:

```bash
grep -rniE "target-system|target_system|TargetSystem" ai/claude/skills/ docs/
```

Then do a broader, less literal pass — an Explore-agent-style search that also looks for indirect mentions (URLs, config keys, abbreviations, or a generic description that clearly means the target system) rather than relying on one exact-match grep. Read surrounding context for every hit; don't trust match count alone.

## 2. Classify each hit

For every reference found, classify it as one of:

- **(a) Live routing logic** — an `if`/routing rule, a trigger condition, or a default destination that will actually break or misroute if left unchanged. These are the ones that matter most.

- **(b) Doc mention or example** — the system is named as an example, a comparison, or in prose that doesn't drive any routing decision. Still worth updating for accuracy, but not a correctness risk if missed.

- **(c) Historical/changelog mention** — a past-tense reference (a completed migration note, a changelog entry, a "previously used X" aside) that should be left alone. Changing history to match the present is its own kind of error.

Record the classification next to each hit before editing anything — this list is what Step 4's verification checks against.

## 3. Plan the edit per hit

Before touching files, do a lightweight plan-mode pass over the classified list: what each file's edit will say, in one line per hit. This is a mechanical multi-file edit, not new functionality — skip the full `dev-team` pipeline (Architect/Coder/Tester) unless a hit turns out to need actual logic changes, not just text substitution.

## 4. Apply edits per-file

Work through the list file by file. Keep edits scoped to what the plan in Step 3 called for — don't use the sweep as an excuse to also rewrite unrelated parts of a file.

## 5. Grep-verify zero remaining live references

**⚠️ Do not assume the sweep is complete just because every planned edit landed.** This step is the actual gate — an incomplete survey in Step 1 means Step 4 quietly fixes less than everything, and nothing else will catch that.

Re-run the same searches from Step 1 against the now-edited corpus:

```bash
grep -rniE "target-system|target_system|TargetSystem" ai/claude/skills/ docs/
```

Any hit remaining must be a Step 2 category (c) historical mention — confirm each one by re-reading it, don't just count that the number went down. If any category (a) or (b) hit survives, go back to Step 4.

## 6. Report a change summary

List every file touched and what changed in each, so the sweep is auditable after the fact — not just "updated N files." Include files that were surveyed and classified as category (c) and deliberately left alone, so a reviewer can tell "left alone on purpose" apart from "missed."

## Relationship to other skills

- **`dev-team`** — use instead of this skill's lightweight Step 3 planning when a hit needs actual new logic, not a mechanical text/reference change.
- **`skill-review`** — a corpus sweep is not a skill quality review; run `skill-review` separately if the sweep surfaces a skill that also needs a broader tune-up.
- **`git-ops`** — commit and PR mechanics for the resulting multi-file diff follow `git-ops` as usual.
