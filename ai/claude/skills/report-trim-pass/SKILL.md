---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: report-trim-pass
description: Pre-delivery brevity/detail check for status-report drafts (weekly-report, comms-write, similar recurring-audience comms) — run after drafting, before showing the user. Checks each bullet against THIS audience's established norm via precedent (prior reports/messages), not a generic "shorter is better" rule. Catches multi-sentence writeups where the audience wants one line, ticket numbers they don't track, internal-process detail when they want outcomes only. No precedent found → default to maximal brevity, let the user ask for more. Different from `humanizer` (style tells, not length) and `doc-audience-check` (context leakage, not brevity). Use before sending a recurring status report or comms draft, or on "trim this report", "check this against how they usually get updates", "is this too long for them", "cut to their usual length", "does this match what they normally get".
compatibility: none
---

# Report Trim Pass

A narrow pre-delivery check for status-report-style drafts: does each bullet match *this specific recurring audience's* established brevity/detail norm, calibrated from precedent rather than a generic length rule. Run this **after** content is drafted and **before** presenting it to the user — it's a last-mile check, not a drafting step.

## Scope

- **In scope**: status-report and comms-style output with a recurring audience — `weekly-report` sections, `comms-write` status updates/3Ps, and similar. The two most likely callers are those two skills; invoke this pass at their draft-complete step, before showing the draft.
- **Out of scope**: one-off messages with no recurring audience (no precedent to calibrate against — nothing for this skill to check).
- **Not `humanizer`**: humanizer fixes AI-writing style tells (vocabulary, formatting, puffery) — a different axis entirely. A bullet can be perfectly "human-sounding" prose and still be three sentences longer than this audience ever wants. Run this pass on content, humanizer on phrasing; order doesn't matter between them since they touch different axes.
- **Not `doc-audience-check`**: that skill catches context leakage — asides answering unstated questions, references introduced with no context, chat-history-ordered sections. This skill doesn't check whether the content makes sense to the reader; it checks whether the *amount* of it matches what this reader is used to getting.

## The check

For each drafted bullet or section, ask: **does this match the established brevity/detail norm for this specific audience** — not "could this be shorter" in the abstract.

Concrete failure patterns to watch for:

- **Length mismatch** — a multi-sentence writeup where this audience has historically received a single line for the same kind of update.
- **Ticket/issue numbers** — included when this audience doesn't track work by ticket number (check precedent for whether numbers ever appear).
- **Internal-process detail** — describing *how* something was done (steps taken, tools used, internal back-and-forth) when this audience's precedent shows they only want *what* happened.

## Mechanism: calibrate from precedent, not a fixed rule

"Established norm" means what this audience has actually received before, not a generic brevity heuristic. Before flagging or trimming anything, look for precedent:

- **Prior reports to the same audience** — e.g. `git log`/prior versions of a recurring report file, or the last few sent instances of a weekly update.
- **Prior sent messages**, if a message archive is available (e.g. a comms log or vault of previously sent Slack/email updates) — check for one before assuming none exists.

Use whatever precedent exists to answer, per bullet type: how long does this audience's version of this bullet usually run, and does it usually include ticket numbers or process detail? Trim (or leave alone) to match — don't apply a fixed word count across audiences.

**No precedent found** (first report to a new audience, or no accessible history): default to maximal brevity. State outcomes only, omit ticket numbers and process detail, one line per item where possible. Let the user expand what they want more detail on — don't guess at verbosity in the other direction.

## Process

1. Identify the audience this draft is going to (from the calling skill's context — e.g. `weekly-report`'s configured rhythm, or `comms-write`'s target channel/recipient).
2. Look for precedent for that audience (prior reports, prior sent messages). Note whether any was found.
3. Walk each bullet/section against the three failure patterns above, using precedent (or the no-precedent default) as the bar.
4. Apply trims directly to the draft. Don't ask the user to approve each cut — this pass exists specifically so they don't have to catch these turn-by-turn.
5. If a bullet is genuinely ambiguous (precedent conflicts, or the content doesn't map cleanly to any prior bullet type), leave it and note the ambiguity briefly rather than guessing.
6. Present the trimmed draft as the one shown to the user — this is a silent pre-delivery step, not a separate review the user has to read through.
