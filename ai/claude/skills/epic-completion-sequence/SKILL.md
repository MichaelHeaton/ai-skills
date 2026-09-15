---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: epic-completion-sequence
description: Close out a parent epic once its child tickets have been closed — re-verify every linked child is genuinely closed (not just checklist-ticked), compose a structured completion-summary comment that cites which children shipped (one-liner each) and flags any follow-on tickets spun off from the epic that are still open, then close the parent. Delegates the actual comment-write, close/transition, and validate-comment-verify-transition ordering to issue-update and ticket-close-sequence rather than reimplementing them. Use when all of an epic's children have just been closed, when asked to "close out this epic", "wrap up the epic", "is this epic done", "check if we can close #X (epic)", or "write the epic completion summary". For closing a batch of unrelated or non-epic-shaped tickets, use ticket-close-sequence directly; for a single non-epic ticket, issue-update alone is enough.
compatibility: Requires issue-update and ticket-close-sequence (both global — ai-skills) for the actual read/comment/close calls. Works across GitHub Issues, GitLab Issues, and Jira via those skills' per-system commands.
---

# Epic Completion Sequence

An epic closing right after its children doesn't just need every child transitioned — it needs a record, on the epic itself, of what actually shipped and what didn't. This skill is a thin, epic-specific addition on top of two existing skills. It does not reimplement ticket validation, comment-posting, or transitions.

## Overlap with existing skills (read this before using)

`issue-update`'s "Bulk operations" section already states the core ordering: *"Closing a parent epic and its children in the same batch: children first, parent last. Close each child, verify each is actually `CLOSED`, then close the parent with a completion summary referencing them."* `ticket-close-sequence` supplies the generic per-ticket discipline (validate → comment → verify → transition) that each of those child closes — and the parent close — should already be following.

Neither skill specifies **what the completion summary comment should actually contain**. `issue-update` says "referencing them" with no structure; `ticket-close-sequence` has no concept of "epic" or "child" at all. That gap — the structured comment format, plus the requirement to surface still-open follow-on tickets — is the only thing this skill adds. Everything else below routes back through those two skills.

## When this applies

- All (or apparently all) of an epic's linked child tickets have just been closed in this session, or
- The user asks to check whether an epic can be closed, or to close one out.

## Steps

### 1. Re-verify every child is actually closed

Do not trust a checklist in the epic body, a task list someone else ticked, or your own memory of closing them earlier in the session — re-fetch each child's live status.

- Pull the epic body/description and extract every linked child ticket (checklist items, sub-issue links, or an explicit "Children" section).
- For each one, fetch its current status via `issue-get` (or the system's own view command) — not from a cached list.
- If any child is not actually closed (open, in-progress, or reopened since it was last checked), **stop** — do not close the parent. Report which child(ren) are still open instead.

### 2. Identify open follow-on tickets

Follow-on work spun off *from* the epic (bugs found during the work, deferred scope, "do this later" tickets referencing the epic) is easy to lose track of once the epic closes, because nothing else points back at it afterward.

- Search for tickets that reference the epic ID (title, body, or a "Refs #epic" style link) but are **not** in the epic's own child list.
- Filter to the ones still open.
- If none exist, the summary comment says so explicitly ("No open follow-ons") rather than omitting the section — an absent section reads as "nobody checked," not "there are none."

### 3. Compose the structured completion-summary comment

Post this via `issue-update`'s comment command for the target system (`gh issue comment`, `glab issue note`, or `jira_add_comment`) — not a raw API/MCP call.

```
**Epic complete** — YYYY-MM-DD

Shipped:
- #94 — <one-line description of what this child did>
- #95 — <one-line description>
- #96 — <one-line description>

Open follow-ons (not part of this epic's completion):
- #101 — <why it's still open / what it covers>

(or: "No open follow-ons.")
```

Keep each child's line to one sentence — this is a pointer for someone landing on the closed epic later, not a re-derivation of each child's own history.

### 4. Verify and close the parent

Route this through the existing sequence rather than a raw transition call:

1. **Verify the comment landed** — re-fetch the epic and confirm the completion-summary comment posted without mangling (see `ticket-close-sequence` step 3 / `ticket-write-verify` if escaping artifacts show up).
2. **Transition** — only after the comment is confirmed, close the parent epic via `issue-update`'s close command for that system.
3. **Sync the task index** — `issue-update` step 4 already covers this; don't duplicate it here.

**Never close the parent before both the child-verification (step 1) and the comment (steps 2-3 above) are confirmed.** If step 1 found an open child, or the comment failed to post cleanly, stop and report — do not close the epic in a partial state.

## Report

```
✓ Epic #80 — 3/3 children verified closed, completion summary posted, 1 open follow-on flagged (#101), epic closed
✗ Epic #80 — child #96 still open, epic NOT closed
```
