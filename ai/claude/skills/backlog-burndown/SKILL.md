---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: backlog-burndown
description: Orchestrated ticket-cleanup pass over a project's open backlog — pulls tickets, groups them by size/risk, makes sure each one has a real Test Plan before touching code, routes implementation through dev-team or a direct edit depending on size, validates every diff against its Test Plan before closing, and reports a per-ticket summary. Use for a batch backlog cleanup session, "burn down the backlog", "close out these tickets", "process the open ticket queue", or an unattended/scheduled cleanup pass. Complements issue-triage (splits an oversized ticket, doesn't implement anything) and dev-team (builds one ticket end-to-end, doesn't orchestrate a batch or gate on Test Plans).
compatibility: Requires gh CLI, glab CLI, or Jira MCP depending on target system. Orchestrates the issue-list, dev-team, ac-conformance-check, and ticket-close-sequence skills rather than reimplementing them.
---

# Backlog Burndown

This is the orchestration layer, not a new implementation or closing mechanism — every step below delegates to a skill that already owns that piece, so a burndown pass can't drift from the guarantees each one already provides (dev-team's adversarial Tester pass, ticket-close-sequence's validate-before-transition gate).

**Known limitation for scheduled/unattended runs**: if this skill is invoked via a fresh-session Routine (`create_trigger` with `create_new_session_on_fire: true`), the spawned session currently has no way to attach push access to the target repo — see `local-automation-setup`'s "Known limitation: fresh-session Routines can't attach repo access" section _(global: ai-skills)_, tracked in [ai-skills#379](https://github.com/MichaelHeaton/ai-skills/issues/379). Until that's resolved, run scheduled burndown passes interactively in a session that already has repo access, or bind the Routine to an already-attached persistent session (trading away completion notifications, per that same section) — don't rely on a bare fresh-session weekly trigger to actually close anything.

## 1. Pull and group tickets

Pull open tickets via `issue-list` _(global: ai-skills)_, scoped to whatever the user named (a repo, a project, a label). Group each into one of two lanes:

- **Trivial** — a direct one-line-or-few-line fix, no ambiguity in approach. Handled in this session directly.
- **Non-trivial** — anything else. Routes through `dev-team` _(global: ai-skills)_, whose own Architect step exists precisely to catch ambiguity on real work.

Use `dev-team`'s own carve-out as the boundary: if a ticket would qualify for dev-team's "do NOT use for a quick one-line fix" exclusion, it's trivial here too. When genuinely unsure which lane a ticket belongs in, default to non-trivial — a wrongly-escalated trivial ticket costs a fast Architect pass; a wrongly-trivialized real ticket costs a shipped bug with no plan review.

**Present the grouped list before starting anything** — a table of ticket, lane, and one-line reason — so the user can move a ticket between lanes before implementation begins.

## 2. Confirm a Test Plan exists

For each ticket, check for a `## Test Plan` section (required on tickets created after 2026-08-14 per `issue-create`'s `user-story-template.md`; older tickets may only have Acceptance Criteria).

- **Has a Test Plan** — proceed to implementation.
- **Legacy ticket, AC only, values are concrete** (specific thresholds, flags, named resources) — defer to `ac-conformance-check` _(global: ai-skills)_ at validation time instead of drafting a new Test Plan; its AC-diff check covers the same ground.
- **Legacy ticket, no checkable AC or Test Plan at all** — draft a concrete Test Plan via a **comment** on the ticket (never a body edit — see `issue-update`'s description-edit policy) before implementing, so the gate in step 4 has something to validate against.

## 3. Implement

**Before implementing either lane**, run the two deterministic checks `dev-team`'s Architect step normally does first: is the ticket already resolved (check `git log`/`git blame` against the described files/behavior — a prior commit may have fixed it without referencing the ticket), and does its fix location resolve to a different repo than the one it's filed in (a symlink or deployed-copy convention — see `git-ops`'s "Worktree path safety when editing" section). The non-trivial lane gets both checks automatically as part of `dev-team`'s own Architect step; the trivial lane skips Architect entirely, so run them explicitly here instead of assuming a "quick" ticket is exempt from them.

- **Trivial lane** — edit directly in this session, same branch/commit discipline `git-ops` requires for any change.
- **Non-trivial lane** — run the ticket through `dev-team`'s full pipeline (Architect plan → approval → Coder → Tester → conditional Docs/Manager). Use `dev-team`'s own batch mode when working several non-trivial tickets in the same pass (batched plan approval, self-polled PR merge state, mandatory direct diff verification per ticket).

## 4. Validate against the Test Plan

Before treating any ticket as done, confirm its Test Plan was actually exercised against the shipped diff — steps genuinely run, not just read and judged plausible:

- **Test Plan ticket** — run each checkable step yourself if `dev-team`'s Tester didn't already exercise it as part of adversarial testing.
- **AC-only legacy ticket** — run `ac-conformance-check` against the diff.
- **A step fails** — stop for that ticket. Do not proceed to closing. Record it as "implemented, not validated" in the final report, with the specific failing step, and move on to the next ticket rather than blocking the whole batch.

## 5. Close

Route every ticket that passed validation through `ticket-close-sequence` _(global: ai-skills)_ — its validate → comment → verify → transition order is exactly this skill's own step-4 gate plus the comment/verify/transition mechanics, so don't re-implement that sequence here. Tickets that failed step 4 skip this entirely; leave them open.

## 6. Report

One line per ticket, plus a batch total:

```
✓ #94 — trivial, implemented, validated, closed
✓ #95 — non-trivial (dev-team), implemented, validated, closed
✗ #96 — non-trivial, implemented, Test Plan step 2 failed — NOT closed, needs rework
⏭ #97 — skipped: ambiguous scope, deferred to user

4 tickets processed — 2 closed, 1 needs rework, 1 skipped
```

Don't report a ticket as closed unless steps 4 and 5 both actually completed for it — a batch summary is only useful if "closed" in the report means the same thing as "closed" in the ticket system.
