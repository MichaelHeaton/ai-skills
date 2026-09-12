---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: monitoring-gap-audit
description: Run a structured post-incident audit after monitoring failed to catch or surface an application-level outage — confirm which observability stack actually ingests the failing service, identify the specific coverage gap (no alert rule, no stream feeding an existing rule, or a rule/threshold that wouldn't have caught this failure shape), propose a concrete fix, and file a tracking ticket for it. Trigger on "monitoring missed this", "why didn't we get paged", "post-incident observability audit", "monitoring gap audit", "we recovered via kubectl logs instead of an alert", or any post-incident retro where recovery happened through a manual/out-of-band path (direct log tailing, manual health check) rather than an alert. Not for use mid-incident — this runs after recovery, as a retro/hygiene step. Ends only when a gap ticket is actually filed via `issue-create`, not on chat-only advice.
compatibility: Requires the `observability-stack-router` skill for stack determination and `issue-create` for filing the resulting ticket. Cloud-compatible — no local-machine-only paths or tooling.
---

# Monitoring Gap Audit

An HTTP blackbox check can stay green through an application-level failure that never touches the health endpoint. When recovery happens through `kubectl logs` or another manual path instead of an alert firing, that's a signal the monitoring coverage has a hole — and holes rediscovered from memory next incident are holes that never get fixed. This skill turns "monitoring missed it" into a documented gap and a filed ticket.

## Trigger condition

Run this **after** an incident is already resolved, specifically when recovery happened through some path other than the monitoring/alerting stack actually catching it — direct `kubectl logs`, a manual health check, a user report, or similar. If an alert did fire and did what it should, there's no gap to audit here.

Skip this mid-incident. This is a retro step, not a response tool.

## Step 1: Confirm which stack actually ingests the failing service

Don't assume "no alert fired" means "nothing was wrong" or "no coverage exists" — an empty query result is ambiguous. It could mean the service was fine, the query hit the wrong stack, or the service was never ingested by any stack at all.

Hand this off to **`observability-stack-router`** rather than re-deriving stack determination here — it was built specifically to disambiguate cloud vs. local (or another documented alternative) before trusting an empty result. Follow its steps to confirm which stack, if any, actually ingests this service's logs/metrics, and get a real answer rather than a guess.

Once routing is settled, **`infra-state-verify`**'s framing applies to how you talk about the result: don't assert what the alerting setup *should* have caught based on reading a Terraform module, Helm values file, or alert-rule definition alone — confirm what's actually configured and active in the live stack before describing the gap.

## Step 2: Identify the specific gap

"Improve monitoring" is not a gap description. Narrow it to exactly one of these three shapes:

- **No alert rule configured** for this failure mode at all — the stack ingests relevant data, but nothing was ever defined to watch for this condition.
- **Alert rule exists, but no stream feeds it** — the rule is defined, but the log/metric stream it depends on was never wired up for this service (e.g. the service's pods don't ship to the stack the rule queries).
- **Stream and rule both exist, but the condition is wrong for this failure shape** — data was flowing and a rule was active, but its threshold, query, or condition wouldn't have fired for this specific kind of failure (e.g. a blackbox check on `/health` that stays green while an internal dependency fails).

State which one applies, and cite what you actually confirmed in Step 1 to support it — not an assumption about what the alerting platform does internally.

## Step 3: Propose a concrete fix

Match the fix to the gap identified in Step 2. Name specifics, not directions:

- **No rule** → the exact alert rule to add (metric/log query, threshold, for-duration, target service).
- **No stream** → the exact log/metric stream to wire up (which service, which stack, which scrape/ingestion config).
- **Wrong condition** → the exact change to the existing rule's query or threshold, and why it would have caught this failure shape.

"Add more monitoring" or "improve alerting" is not an acceptable output of this step — if the proposal can't name a rule, a stream, or a specific condition change, it isn't specific enough yet.

## Step 4: File the gap ticket — this is not optional

This skill's job isn't done until a tracking ticket exists. Chat-only advice does not satisfy it.

File the ticket through **`issue-create`** — never a direct `gh issue create` or a ticketing MCP tool call. Include:

- Which service, and the incident it traces back to (genericized if the session context requires it)
- Which stack was confirmed to (or fail to) ingest it, from Step 1
- The specific gap shape from Step 2
- The concrete proposed fix from Step 3

Report the filed ticket's ID/URL back to the user as this skill's closing output — a summary with no ticket link means the skill didn't finish.
