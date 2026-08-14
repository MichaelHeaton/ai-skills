---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: issue-batch
description: Create several tickets at once from a natural-language list, each with a properly structured body and task-index entry, in a single pass instead of repeated one-off issue-create invocations. Use when the user describes 5-15 work items at once — "make tickets for X, Y, Z, and W", "break this list into issues", "file these as separate tickets" — and they all belong in the same system/repo. For a single ticket, or items that need to land in different systems, use issue-create directly.
compatibility: Requires gh CLI, Atlassian MCP, or Linear MCP depending on target system.
---

# Issue Batch

Bulk ticket creation from a list, reusing `issue-create`'s routing and template logic instead of duplicating it — this skill is the batching layer on top, not a separate creation path.

## 1. Parse the list

Break the user's natural-language description into discrete work items. A well-formed list usually has clear separators (bullets, "and", numbered items) — if the boundary between two items is ambiguous, ask once rather than guessing a split that might merge or over-split real items.

## 2. Detect routing (once, for the whole batch)

Run `issue-create`'s routing detection (`detect-context.sh` or an explicit repo/system named by the user) **once** — bulk creation only makes sense when every item goes to the same target system and repo.

**If the items don't all belong in the same place** (e.g. some read as work-repo Jira Stories, others as personal GitHub issues), stop and tell the user: route each group separately through `issue-create`, or confirm they actually do all belong in one place before proceeding.

## 3. Draft each item

For each work item, draft a body using `issue-create`'s user-story template (§C2 / the routed path's equivalent) — goal, scope, acceptance criteria. Keep each draft self-contained; don't assume the reader has the other items' context.

## 4. Present for review

Show a summary table before creating anything — this step never skips, even when the confirmation wait below does:

```
| # | Title | Priority |
|---|-------|----------|
| 1 | Add retry to the sync job | medium |
| 2 | Document the webhook payload shape | low |
| 3 | Fix flaky auth test | high |
```

**Wait for confirmation** when the request was open-ended — "let's file some tickets", "should we track this somewhere?" Let the user adjust titles, drop items, or split/merge before any ticket is created.

**Skip the wait when the request already authorizes creation** — imperative phrasing like "create tickets for X and Y" or "make tickets for A, B, and C" already is the confirmation; asking "should I create these?" afterward is redundant friction. Show the summary table for visibility, then proceed straight to Step 5. When phrasing is ambiguous between the two, default to waiting.

## 5. Create in parallel, index sequentially

Once approved:

1. Run all creation calls (`gh issue create`, `jira_create_issue`, or Linear's `save_issue`) in parallel for speed.
2. After all creations return, append each one to the task index **sequentially** — per `issue-create`'s own batch-creation guidance, this step is never optional even when the per-issue flow was skipped for parallelism; a missing index entry means the ticket won't surface in `session-close` or `issue-list`.

## 6. Confirm

Report each created ticket as a markdown link, plus the total: "Created 5 tickets in `owner/repo` — [#101](url), [#102](url), [#103](url), [#104](url), [#105](url)."
