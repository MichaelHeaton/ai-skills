---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: incident-capture
description: Capture a structured post-mortem the moment a live incident is confirmed resolved — timeline, root cause, recovery steps, follow-up risks — instead of letting the detail scatter across ad hoc notes and disappear once the pressure is off. Use immediately after confirming an incident is resolved, or when asked "write up what just happened", "capture a post-mortem", or "document this incident before we forget the details".
compatibility: None — works with any doc/wiki/ticket system for the write-up destination.
---

# Incident Capture

Post-mortem detail decays fast — the exact sequence of what was tried, in what order, with what result, is clear for about an hour after resolution and fuzzy by the next day. Capture it at the moment of resolution, not "later when there's time."

## 1. Confirm resolution first

Only run this once the incident is actually resolved (or confirmed stable enough that active firefighting has stopped) — capturing mid-incident competes with actually fixing the problem, and a mid-incident write-up gets outdated by the next development anyway.

## 2. Reconstruct the timeline

Pull from whatever's available — chat logs, command history, monitoring alerts, ticket comments — to build a chronological sequence: when it started (or was first noticed), what was tried and when, what worked, when it was confirmed resolved. Timestamps matter more than prose here; a bare timeline is more useful later than a narrative missing the actual times.

## 3. Root cause

State the actual root cause, not just the symptom that triggered the alert — "disk filled up" is a symptom; "log rotation was misconfigured after a deploy three weeks ago" is a root cause. If the root cause genuinely isn't known yet, say that explicitly rather than writing a plausible-sounding guess as fact.

## 4. Recovery steps taken

List what was actually done to resolve it, in order — including things tried that didn't work, since "we tried X first, it didn't help, then Y worked" is exactly the information that saves time next time this happens.

## 5. Follow-up risks and tickets

- What's still fragile after this recovery (a manual workaround still in place, a monitoring gap that let this go undetected longer than it should have)?
- File tickets for anything that needs real follow-up work — don't leave "we should probably fix X" as a stray sentence in the write-up with no tracking.

## 6. Cross-link

- Link the write-up from the incident's tracking ticket (and vice versa)
- If a runbook exists (or should exist) for this class of incident, cross-link it too — and consider running `ops-runbook-update` _(global: ai-skills)_ if the runbook needs correcting based on what actually happened this time

## 7. Write-up location

Save to wherever the team's post-mortems normally live — a wiki, a docs folder, a ticket comment thread. Consistency of location matters more than the specific choice; a post-mortem nobody can find later has the same value as one that was never written.
