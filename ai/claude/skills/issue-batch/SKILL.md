---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: issue-batch
description: Create several tickets at once from a natural-language list, each with a properly structured body and task-index entry, in a single pass instead of repeated one-off issue-create invocations. Use when the user describes 5-15 work items at once — "make tickets for X, Y, Z, and W", "break this list into issues", "file these as separate tickets" — and they all belong in the same system/repo. For a single ticket, or items that need to land in different systems, use issue-create directly.
compatibility: Requires gh CLI or Atlassian MCP depending on target system.
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

**If the ticket list emerged from an in-progress investigation or discussion rather than an already-finalized plan**, flag that a follow-up restructuring pass is likely before batching — or suggest holding off until the user signals the plan is actually final (an explicit "let's create these" after a settled discussion, not mid-investigation). A plan still being actively negotiated is a different case from an open-ended-but-settled request; treating it the same risks creating tickets that get extensively rewritten across several follow-up turns.

## 5. Create in parallel, index sequentially

**For a GitHub-routed batch (Path B/C), run `issue-create`'s Step 0.5 sandbox/auth probe once before starting the parallel loop below — never skip straight to parallel creates.** A sandboxed `GraphQL: Forbidden` hits every parallel `gh issue create` call identically, and an unchecked batch will silently produce N empty-looking `CREATED=` lines instead of one clear failure. One upfront probe catches this before it can masquerade as N separate mysteries.

- **Probe fails** (per issue-create Step 0.5: token/account mismatch, or the `required_permissions: ["all"]` retry and REST fallback both dead-end): **abort the whole batch now.** Report one clear error — which probe step failed and why — and do not run any of the parallel creates in step 1 below. Do not let individual creates fail silently one-by-one; a single upfront failure is far easier to diagnose and fix than a batch that half-completed with no indication which items actually landed.
- **Probe succeeds**: proceed with the parallel loop exactly as before — this check adds one auth call up front, nothing else changes on the happy path.

Jira-routed batches (Path A) have no equivalent sandbox failure mode — skip the probe and proceed directly to the parallel loop.

Once approved (and, for GitHub, once the probe above has succeeded):

1. Run all creation calls (`gh issue create` or `jira_create_issue`) in parallel for speed.
2. After all creations return, append each one to the task index **sequentially** — per `issue-create`'s own batch-creation guidance, this step is never optional even when the per-issue flow was skipped for parallelism; a missing index entry means the ticket won't surface in `session-close` or `issue-list`.

## 6. Confirm

Report each created ticket as a markdown link, plus the total: "Created 5 tickets in `owner/repo` — [#101](url), [#102](url), [#103](url), [#104](url), [#105](url)."
