---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: grafana-alert-triage
description: MCP-driven triage for noisy or flapping Grafana Cloud alerts — inspect contact points, notification policies, and alert rules read-only, diagnose flap causes (for-duration, threshold), and propose a retune via IaC/git PR. When the Grafana MCP lacks write scope (403 on a silence or contact-point PUT), stop and hand off with a proposed change plus a ticket instead of retrying the blocked write. Use for "alert is flapping", "too noisy alert", "retune this alert threshold", "grafana contact point", "notification policy", "silence this alert", or "MCP got a 403 on grafana". Complements iac-triage (once the retune becomes a real Terraform/config PR) and issue-create (for the handoff ticket).
compatibility: Requires a Grafana Cloud MCP server connection. Write-scoped operations (silences, contact-point PUT) may be read-only or blocked depending on the token's scope.
---

# Grafana Alert Triage

Structured triage for a noisy or flapping Grafana Cloud alert: inspect via MCP, diagnose the cause, and prefer a git-reviewed retune over a live UI edit. Read-only inspection is always safe to run; anything that writes to Grafana is gated and has an explicit fallback when the MCP token can't do it.

## Read-only steps (always safe, no write scope needed)

### Step 1 — Inspect the alerting rule

Use the Grafana MCP to fetch the alert rule definition: current threshold, `for` duration, evaluation interval, and the query it evaluates. Note the rule's current state history if the MCP exposes it — how often it's transitioned firing/resolved recently is the key flap signal.

### Step 2 — Inspect notification policy and contact point routing

Fetch the notification policy tree and the contact point(s) the flapping alert routes through. Confirm the alert is routed where expected — a policy misroute (alert firing correctly but hitting the wrong contact point, or a contact point silently misconfigured) looks identical to alert-level noise from the receiving end.

### Step 3 — Diagnose the flap

Common causes, in order of how often they explain flapping:

- **`for` duration too short relative to metric noise** — the underlying signal crosses the threshold briefly and resolves before it's a real incident. Lengthening `for` is usually the right fix, not raising the threshold.
- **Threshold set at the noise floor** — the metric normally oscillates near the threshold. This needs an actual threshold retune, informed by the metric's real baseline (pull a wider time range, not just the recent flapping window).
- **Evaluation interval mismatched to metric scrape interval** — evaluating faster than the metric updates can double-count the same underlying change as multiple transitions.

Pick the cause that matches what Steps 1–2 actually showed — don't retune blind without having looked at the rule's history.

## Write-gated steps (need MCP write scope)

### Step 4 — Prefer IaC / git PR for the retune

If this Grafana instance's alert rules are managed as code (Terraform, Grafana provisioning YAML, or similar), make the retune there and open a normal PR through `git-ops` — do not hand-edit the live rule via MCP or UI when a code path exists. This keeps the change reviewable and prevents the next `terraform apply` / provisioning sync from silently reverting a live-only edit.

### Step 5 — Direct MCP write, only when no IaC path exists

If the rule is genuinely UI-managed with no corresponding code, and a direct fix is appropriate, use the MCP's write operation for the specific field being changed (threshold, `for`, contact point routing). Confirm the change took by re-fetching the rule afterward — don't assume a 200 response means the value landed as intended.

## Handoff when write scope is missing

**⚠️ On a 403 from any write operation (silence, contact-point PUT, notification policy update), do not retry the write.** A 403 means the MCP token's scope doesn't cover writes, not that the request was malformed — retrying with different payloads wastes time and won't change the outcome.

Instead:

1. Write up the proposed change exactly as it would have been applied (the diagnosis from Step 3, the specific field/value to change, and why).
2. Open a ticket via `issue-create` capturing that proposal, tagged for whoever holds write access to make the change.
3. Report back what was diagnosed and that a ticket now tracks the fix — this is a complete triage outcome, not a stalled one.

## Public-repo scrub

Before committing any example, retune value, or rule name into this repo, confirm no employer names, internal hostnames, or secrets appear — use a fictional slug from `categories/tags.yaml` in any example.
