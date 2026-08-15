---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: ticket-close-sequence
description: Close or re-parent a batch of related tickets using a fixed validate-then-comment-then-verify-then-transition order, so a batch run never leaves a ticket transitioned without its fix actually being checked against the ticket's test plan and its rationale landing first. Use when closing several related tickets at once (a milestone wrap-up, a superseded-by cleanup, re-parenting sub-issues), or whenever asked to "close these tickets", "batch-close", "close all the X tickets", or "clean up this group of issues". For a single ticket, issue-update alone is enough — this skill is for the ordering discipline across a batch.
compatibility: Works across Jira, GitHub Issues, and GitLab Issues via issue-update's per-system commands.
---

# Ticket Close Sequence

Closing several tickets in one pass tempts a shortcut: transition first, comment after (or not at all), because the transition call is the one that visibly "finishes" each ticket. This skill enforces the safer order and makes a partial failure visible instead of silent.

## The sequence, per ticket

1. **Validate against the Test Plan** — if the ticket has a `## Test Plan` section (required on tickets created after 2026-08-14; older tickets may only have Acceptance Criteria), confirm each step was actually run against the shipped diff, not just read and judged plausible — re-run it yourself if it wasn't already exercised this session. For AC-only legacy tickets, run `ac-conformance-check` _(global: ai-skills)_ instead. A ticket closing as "fixed" or "built" needs one or the other actually run — a diff that only _looks_ right is not the same as one that was checked.
2. **Comment** — post the reason for closing/re-parenting (why, a link to the superseding ticket/PR/decision if there is one, and which test-plan steps were run and passed). Use `issue-update`'s per-system comment command.
3. **Verify the comment landed** — re-fetch the ticket and confirm the comment is present. Some systems (Jira in particular) can silently mangle or drop the write — see `ticket-write-verify` _(global: ai-skills)_ if the re-fetch shows escaping artifacts rather than a missing comment outright.
4. **Transition** — only after step 3 confirms the comment is there, close or re-parent the ticket.

**Never transition before validation and the comment are both confirmed.** If step 1 finds the test plan wasn't actually run (or can't pass), stop — do not transition, and say so in the report rather than closing a ticket whose fix hasn't been checked. If step 3 fails (comment didn't post, or posted mangled beyond what a quick fix resolves), stop for that ticket too — do not transition it, and do not silently skip to the next one. Flag it explicitly in the final report as "needs manual comment" or "test plan not validated" rather than letting it disappear from the summary.

**Exception:** tickets whose AC/Test Plan is itself "N/A — no executable behavior" (pure research, docs, or ticket-creation work) skip step 1 — there's nothing to run.

## Batch execution

Process the list of tickets sequentially per ticket (validate → comment → verify → transition, all four before moving to the next ticket) rather than doing all validations first, then all comments, then all verifies, then all transitions — a partial failure on ticket 3 shouldn't leave tickets 4–10 transitioned while ticket 3 sits half-done with no comment or unvalidated fix.

## Report

At the end, summarize per ticket:

```
✓ #94 — closed, test plan validated, comment landed
✓ #95 — re-parented under #80, comment landed
✗ #96 — comment failed to post, NOT transitioned — needs manual follow-up
✗ #97 — test plan step 2 failed against the diff, NOT transitioned — needs rework
```

Do not report a ticket as closed unless the test plan validation (or its documented exception), the comment, and the transition are all confirmed.
