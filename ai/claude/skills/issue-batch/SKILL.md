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

**For a GitHub-routed batch (Path B/C), create the first issue on its own via `gh issue create` (issue-create's normal GraphQL path) before starting the parallel loop below — never skip straight to parallel creates.** A bare auth probe (`gh api user`, a REST call) isn't sufficient on its own: sandbox network ACLs can allow REST while still blocking the GraphQL endpoint `gh issue create` actually uses, so a REST-only probe can report success while every parallel GraphQL create is about to fail identically. Creating the real first issue exercises the exact call the parallel loop depends on, not a proxy for it.

- **First create succeeds via plain `gh issue create`**: GraphQL works in this sandbox. Proceed with the remaining N-1 creates in parallel via `gh issue create` exactly as before — this adds one sequential create up front, nothing else changes on the happy path.
- **First create returns `GraphQL: Forbidden`**: run `issue-create`'s Step 0.5 in full (auth probe → `required_permissions: ["all"]` retry → REST fallback → escalate) to get that first issue created one way or another.
  - **If Step 0.5's REST fallback is what succeeded** (meaning GraphQL is genuinely blocked in this sandbox, not just a one-off): don't parallelize the rest via `gh issue create` — every one of them would hit the identical `Forbidden`. Instead, run the remaining N-1 creates **sequentially via the same REST fallback** (`gh api --method POST repos/<owner>/<repo>/issues`), or abort and report "GraphQL blocked in this sandbox, N-1 more issues to create via REST" if sequential REST creation is itself too slow/risky for the batch size — don't silently fall back to parallel GraphQL calls that are already known to fail.
  - **If Step 0.5 dead-ends entirely** (token/account mismatch unresolved, or the sandbox denies REST too): **abort the whole batch now.** Report one clear error — which Step 0.5 stage failed and why — and do not attempt any further creates. Do not let individual creates fail silently one-by-one; a single upfront failure is far easier to diagnose and fix than a batch that half-completed with no indication which items actually landed.

Jira-routed batches (Path A) have no equivalent sandbox failure mode — skip this check and proceed directly to the parallel loop.

Once approved:

1. **Jira (Path A)**: run all `jira_create_issue` calls in parallel for speed. **GitHub (Path B/C)**: the first issue is already created (per the check above) — for the remaining N-1, follow whichever branch above applied: parallel `gh issue create` calls on the happy path, or sequential REST creates (one at a time, not parallel) if GraphQL turned out to be blocked.
2. After all creations return, append each one to the task index **sequentially** — per `issue-create`'s own batch-creation guidance, this step is never optional even when the per-issue flow was skipped for parallelism; a missing index entry means the ticket won't surface in `session-close` or `issue-list`.

## 6. Confirm

Report each created ticket as a markdown link, plus the total: "Created 5 tickets in `owner/repo` — [#101](url), [#102](url), [#103](url), [#104](url), [#105](url)."
