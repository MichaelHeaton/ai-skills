---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: ops-runbook-update
description: Given a triggering ops event (a disk wearing out, a migration, a network change), find the relevant runbook, update it with what actually happened, cross-link the tracking issue, and bump its date — keeping runbooks and tickets in sync instead of letting the runbook drift stale after the ticket closes. Use right after resolving an infra event that has (or should have) a runbook, or when asked "update the runbook for this", "does this event need a runbook change", or "sync the runbook with what we just did".
compatibility: Requires access to the repo/wiki where runbooks live.
---

# Ops Runbook Update

Runbooks decay silently — an event happens, gets fixed, the ticket closes, and the runbook that described the old procedure never gets touched. The next time the same class of event happens, whoever's on call follows a runbook that's subtly wrong about the current state of things.

## 1. Find the relevant runbook

Search for a runbook matching the event's category (by resource type, by procedure name) — don't assume none exists just because the event felt novel; check first. If genuinely none exists, that's a signal this event is worth turning into a first runbook, not a reason to skip documentation.

## 2. Determine what changed

Compare what the runbook currently says against what actually happened this time:

- Did the procedure work as documented, or did a step need adjusting?
- Did the event surface a new failure mode the runbook doesn't cover?
- Did a referenced tool, command, or threshold change since the runbook was last updated?

## 3. Update the runbook

Apply the update directly — add the new failure mode, correct the stale step, adjust the threshold. Keep the runbook itself procedural (what to do), not a log of every past incident; incident-specific detail belongs in the tracking ticket, not baked permanently into the runbook.

## 4. Cross-link and bump the date

- Add a reference from the runbook to the tracking issue/PR for this event (a "See also" or "Last exercised" line)
- Add a reference from the tracking issue back to the runbook, if the issue doesn't already link it
- Bump the runbook's last-updated marker so staleness is visible at a glance later

## 5. Report

```
✓ docs/runbooks/disk-retirement.md updated — added wearout-threshold check, linked #197
```

If the runbook needed no changes (the procedure worked exactly as documented), say so and just bump the "last exercised" date — that's still useful signal for whoever reads it next.
