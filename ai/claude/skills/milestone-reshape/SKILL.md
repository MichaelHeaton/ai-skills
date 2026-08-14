---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: milestone-reshape
description: Bulk-triage a set of GitHub milestones after a roadmap shift — surface stale or superseded issues, propose close vs. carry-forward for each, reassign survivors to the reshaped milestone ladder, and close emptied milestones. Use after a roadmap change makes the current milestone ladder stale, or when asked "reshape the milestones", "clean up the milestone ladder", or "triage what's in these milestones now that priorities shifted". Distinct from issue-update, which handles single-ticket changes, not a bulk ladder reshape.
compatibility: Requires gh CLI with milestone read/write access.
---

# Milestone Reshape

A roadmap shift leaves the existing milestone ladder stale — issues assigned to milestones that no longer reflect current priorities, some genuinely superseded, others still relevant but now belonging in a different bucket. This is the bulk-triage pass for that whole ladder, not a one-ticket-at-a-time fix.

## 1. Pull the current ladder

```bash
gh api repos/<owner>/<repo>/milestones --paginate
gh issue list --repo <owner>/<repo> --milestone "<milestone-title>" --state open --json number,title,updatedAt
```

Do this for every milestone in scope, not just the ones that feel obviously stale — a milestone that looks fine can still have individual stale issues in it.

## 2. Surface stale/superseded candidates

For each issue, flag as a candidate if:

- It hasn't been updated in a long time relative to the milestone's pace (stale)
- Its subject is clearly covered by a different, already-landed change (superseded)
- The milestone it's in no longer exists in the reshaped roadmap

Present candidates with enough context (title, last updated, brief reason) for a human call — this skill doesn't close anything without confirmation.

## 3. Propose close vs. carry per candidate

```
| # | Title | Last updated | Proposal |
|---|-------|--------------|----------|
| 94 | Add retry to sync job | 2026-05-02 | Carry → v2 |
| 95 | Old dashboard redesign | 2026-03-11 | Close — superseded by #201 |
```

**Wait for confirmation before acting** — a bulk close/reassign is hard to cleanly undo at scale.

## 4. Execute — close vs. carry

- **Close as superseded/stale**: use `ticket-close-sequence` _(global: ai-skills)_ for the comment-then-verify-then-transition ordering across the batch, rather than closing directly.
- **Carry forward**: reassign to the new milestone via `gh issue edit <n> --milestone "<new-milestone>"`.

## 5. Close emptied milestones

Once every issue in a milestone has been closed or reassigned out, close the milestone itself:

```bash
gh api repos/<owner>/<repo>/milestones/<number> -X PATCH -f state=closed
```

## 6. Smart-mode / Auto-review friction

This is a high-velocity batch mutation — expect the same Auto-review smart-mode gate `issue-update` documents for bulk operations. Approve the first smart-mode card when it appears, and group same-shape actions (all closes together, all reassigns together) into contiguous batches so the gate doesn't re-trigger mid-run on what looks like a shape change.

## 7. Report

```
Milestone reshape — v1 Legacy Ladder
Closed (5): #95, #101, #103, #110, #112
Carried to v2 (8): #94, #96, #97, #98, #99, #100, #102, #104
Milestone "v1 Legacy Ladder" — closed (emptied)
```
