---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: impl-preflight
description: Run a quick structured check before starting implementation on a ticket — are its dependencies actually deployed (not just marked done), what existing code patterns apply, what resource decisions need to be locked in first, and are there known constraints that would otherwise surface mid-work as a surprise. Use right before starting work on a ticket, or when asked "is there anything to check before I start X", "is the environment ready for this ticket", "pre-flight before starting <ticket>", or "what do I need before starting this".
compatibility: Requires read access to the ticket, the target codebase, and whatever environment the dependencies live in.
---

# Impl Preflight

Skipping a pre-check before implementation means dependency gaps and constraint surprises get discovered mid-work instead of before it starts — the same category of problem `ac-conformance-check` catches at the *end* of implementation, this catches at the *start*.

## 1. Read the ticket

Extract:

- The stated acceptance criteria
- Any explicitly listed dependencies (a prior ticket, a deployed service, a config value that needs to exist first)

## 2. Verify each dependency is actually ready

**Don't trust "marked done" as "actually deployed."** For each listed dependency:

- If it's a prior ticket: check that its PR actually merged, not just that the ticket shows closed (a ticket can close without its fix landing, per the same gap `git-ops`'s post-merge verification exists for)
- If it's a service/endpoint: check it's actually reachable, not just that a deploy ticket for it exists
- If it's a config value: check it's actually set in the environment this work will run against, not just documented as "should be set"

## 3. Identify applicable existing code patterns

Before writing anything new, look for how the codebase already solves adjacent problems — a similar feature, a similar integration. Note the pattern to follow (or explicitly note there isn't one, meaning this is genuinely new ground).

## 4. Flag resource decisions that need locking in first

Some tickets have an implicit decision point that isn't spelled out in the AC (which of two equivalent approaches, what a new resource should be named, which existing module to extend vs. creating a new one). Surface these now, before code gets written around an assumption that turns out wrong — not discovered after the fact when reworking is expensive.

## 5. Surface known constraints

Anything documented elsewhere (a runbook, a past incident writeup, a comment in adjacent code) that would constrain this implementation — a rate limit, a known fragile integration, a "don't do X here, it broke Y last time." Read commit history and comments near the code this ticket will touch, not just the ticket itself.

## 6. Report

```
Preflight: #142 — add retry to sync job
✓ Dependency: #138 (queue priority change) — merged, verified in main
✗ Dependency: staging endpoint — ticket says deployed, endpoint returns 503
Pattern: follow the retry wrapper in jobs/email_sync.py
Decision needed: exponential vs. fixed backoff — not specified in AC
Constraint: this queue has a known rate limit (see #98's postmortem)
```

A `✗` dependency is a blocker — flag it clearly rather than starting work that assumes it's ready.
