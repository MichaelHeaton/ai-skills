---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: ticket-close-sequence
description: Close or re-parent a batch of related tickets using a fixed comment-then-verify-then-transition order, so a batch run never leaves a ticket transitioned without its rationale landing first. Use when closing several related tickets at once (a milestone wrap-up, a superseded-by cleanup, re-parenting sub-issues), or whenever asked to "close these tickets", "batch-close", "close all the X tickets", or "clean up this group of issues". For a single ticket, issue-update alone is enough — this skill is for the ordering discipline across a batch.
compatibility: Works across Jira, GitHub Issues, GitLab Issues, and Linear via issue-update's per-system commands.
---

# Ticket Close Sequence

Closing several tickets in one pass tempts a shortcut: transition first, comment after (or not at all), because the transition call is the one that visibly "finishes" each ticket. This skill enforces the safer order and makes a partial failure visible instead of silent.

## The sequence, per ticket

1. **Comment** — post the reason for closing/re-parenting (why, and a link to the superseding ticket/PR/decision if there is one). Use `issue-update`'s per-system comment command.
2. **Verify the comment landed** — re-fetch the ticket and confirm the comment is present. Some systems (Jira in particular) can silently mangle or drop the write — see `ticket-write-verify` _(global: ai-skills)_ if the re-fetch shows escaping artifacts rather than a missing comment outright.
3. **Transition** — only after step 2 confirms the comment is there, close or re-parent the ticket.

**Never transition before the comment is confirmed.** If step 2 fails (comment didn't post, or posted mangled beyond what a quick fix resolves), stop for that ticket — do not transition it, and do not silently skip to the next one. Flag it explicitly in the final report as "needs manual comment" rather than letting it disappear from the summary.

## Batch execution

Process the list of tickets sequentially per ticket (comment → verify → transition, all three before moving to the next ticket) rather than doing all comments first, then all verifies, then all transitions — a partial failure on ticket 3 shouldn't leave tickets 4–10 transitioned while ticket 3 sits half-done with no comment.

## Report

At the end, summarize per ticket:

```
✓ #94 — closed, comment landed
✓ #95 — re-parented under #80, comment landed
✗ #96 — comment failed to post, NOT transitioned — needs manual follow-up
```

Do not report a ticket as closed unless both the comment and the transition are confirmed.
