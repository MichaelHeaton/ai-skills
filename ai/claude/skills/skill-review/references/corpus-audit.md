---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-04
updated_by: claude
---

# Corpus-audit variant (multi-file historical scan)

SA1–SA4 assume the corpus is one session's conversation (live, or pre-summarized via the sub-agent pattern). A caller can instead supply a **multi-file historical corpus** — e.g. a batch of files about to be deleted, plus every already-deleted file recoverable from git history — when the goal is to find friction that recurs *across* sessions and dates rather than within a single one.

## When this applies

Any workflow that has to decide whether to discard a batch of session/notes files and wants to check first whether they contain a recurring pattern — the same annoyance, the same manual workaround, the same "noted but not worth fixing" observation — showing up more than once across different dates. The motivating case: a session-close file retention prune, where each individual file was already judged too low-signal to justify a skill change on its own, but recurrence across files is a signal no single session could see.

## Input shape

The caller passes a list of `{date, source (file path or recovered git ref), full text}` for every file in scope — the current about-to-be-deleted batch **and** all historically-deleted files still recoverable via source control. Widen the corpus as far back as history allows; don't cap it to just the current batch, since a pattern that only appears twice needs both occurrences in view to be seen at all.

## What changes vs. a single-session run

- **SA0** — skip. It checks the *live* Claude Code install's skill-usage counters and symlink ages, which say nothing about a historical text corpus.
- **SA1** — "skills used" becomes "skills or workflows mentioned or implied" across all files in the corpus.
- **SA2** — apply only where a corpus item names a specific skill and describes it behaving well or badly; most historical notes won't have this level of detail, and that's fine — skip rather than force it.
- **SA3 is the main event** — look for the same friction, annoyance, or manual workaround appearing in **two or more distinct files/dates**. A single mention is exactly the kind of thing that was already judged not worth a skill change at the time — it's the recurrence, not any one instance, that elevates it.
- **SA4** — same three-list output format (existing skills to improve / new skill ideas / stale skills N/A here), but every finding must cite **at least two source files/dates** as evidence. A finding backed by one file doesn't meet the corpus-mode bar and belongs back in the "noted but not actionable" pile.
- **SA5** — unchanged: ticket via `issue-create`, same public-repo security scrub before writing ticket content.

## Output addition

Prepend a scan summary before the usual SA4 lists, e.g.:

```
Scanned 9 files (2 pending deletion + 7 recovered from prior prune history) — 1 recurring pattern found.
```

If nothing recurs, say so plainly ("no recurring pattern found across N files") — don't manufacture a finding to justify the scan.
