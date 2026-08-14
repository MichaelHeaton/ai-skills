---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: ac-conformance-check
description: Line-by-line diff the values a PR/diff actually changed against a ticket's stated acceptance criteria, so a value silently drifting from what was explicitly asked for doesn't slip through structural, security, or adversarial review — none of which are scoped to "does this match the ticket." Use before merging any PR against a ticket with concrete AC (specific values, thresholds, flags), or when asked to "check this against the ticket", "does this diff actually match what was asked", or "verify AC conformance". Complements, does not replace, fmt/validate, security review, and testing.
compatibility: Requires the ticket's AC text and a diff or plan output to compare against.
---

# AC Conformance Check

`fmt`/`validate` checks code health. Security review checks posture. Adversarial testing checks robustness. None of them check whether the value actually shipped is the value the ticket actually asked for — a build can pass all three and still contradict a plainly stated requirement. This is a narrow, mechanical check that fills that specific gap.

## 1. Extract every concrete AC

Read the ticket's acceptance criteria and pull out every checkable claim with a specific expected value: a config default, a threshold, a flag state, a named resource, a count. Skip AC that's inherently qualitative ("code is readable") — this check is for values, not judgment calls.

```
AC extracted:
- retry_count default = 3
- feature flag `new_auth` = false (not yet enabled)
- timeout = 30s
```

## 2. Map each AC to the diff

For each extracted AC, find the corresponding line(s) in the diff or plan output that are supposed to satisfy it. Three outcomes per AC:

- **Match** — the diff sets the value the AC specifies
- **Contradiction** — the diff sets a *different* value than the AC specifies (the failure mode this check exists to catch)
- **No corresponding change** — the AC isn't addressed by this diff at all (may be intentional — a follow-on ticket — or a missed requirement)

## 3. Report

```
AC conformance:
✓ retry_count = 3 (matches diff)
✗ feature flag `new_auth` = true in diff, AC says false — CONTRADICTION
⚠ timeout AC not addressed by this diff
```

A single `CONTRADICTION` is a blocker — surface it clearly, don't bury it in a longer summary. `⚠` items need a judgment call (intentional deferral vs. missed requirement), not an automatic fail.

## 4. Scope discipline

This check is deliberately narrow — it doesn't replace structural review, security review, or testing, and it doesn't evaluate whether the AC itself was a good idea. It answers exactly one question per AC: does the diff's value match what was asked for. Keep it that scoped; a broader "is this a good change" judgment belongs to the other review lenses.
