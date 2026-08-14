---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: doc-sweep-after-correction
description: After correcting a factual mistake or wrong assumption in one doc, sweep the rest of the repo (and linked wiki/external docs) for other statements of the same now-wrong assumption, so a single fix doesn't leave the correction half-applied. Use right after confirming a correction in an infrastructure/docs-heavy repo — "that assumption was wrong, I fixed it here" — or when asked "check if this is stated anywhere else", "sweep the docs for this", or "did we say this wrong somewhere else too".
compatibility: Requires grep/ripgrep access to the repo (and any linked wiki, if applicable).
---

# Doc Sweep After Correction

A wrong assumption baked into a system's docs is rarely stated in just one place — a repo with several interlinked docs describing the same system tends to repeat the same fact in a README, a runbook, and a comment. Fixing it in the doc where it was noticed and stopping there leaves the others silently wrong, discovered one at a time in later sessions.

## 1. Extract the corrected claim

State, precisely, what was wrong and what's now correct — not the surrounding prose, just the factual claim itself:

```
Was: "the retry queue processes in FIFO order"
Now: "the retry queue processes by priority, not FIFO"
```

A precise before/after pair is what makes the grep in step 2 effective — a vague "fixed the queue docs" doesn't give you a search target.

## 2. Sweep for other statements

Grep the repo for the old claim's key terms — not an exact string match (the wrong wording likely varies slightly across docs), but the concept:

```bash
grep -ril "FIFO" --include="*.md" .
```

Check each hit: does it restate the same now-wrong claim, or is it an unrelated correct use of the term? Only the former needs fixing.

**If the repo links to an external wiki or a linked docs site**, sweep there too — the pattern that motivated this skill was exactly a doc fixed in one PR, followed by a second PR shortly after syncing a related doc that still had the old assumption; catching both in one pass avoids the second PR.

## 3. Fix each hit found

Apply the same correction to each confirmed hit, keeping the wording natural to that doc's context rather than copy-pasting the exact sentence from the original fix.

## 4. Report

```
Swept for "FIFO" claim after correcting docs/queue-architecture.md.
Also corrected: README.md, docs/runbooks/queue-recovery.md
Not corrected (unrelated use of "FIFO"): docs/glossary.md
```

If the sweep finds nothing else, say so — a clean sweep is a valid, useful result, not a sign the check didn't work.
