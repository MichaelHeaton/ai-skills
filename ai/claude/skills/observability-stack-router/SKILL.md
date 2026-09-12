---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: observability-stack-router
description: Before querying logs or metrics (Loki, Prometheus, Grafana, or similar) for a specific host or service, disambiguate which observability stack actually ingests it — cloud vs. local/on-prem, or another documented alternative — so an empty result from the wrong endpoint isn't mistaken for "the host is healthy and quiet." Trigger only when it's genuinely unclear which stack covers the target host, not on every observability query — a host already confirmed to live in one stack this session doesn't need re-routing. Checks for an explicit mapping (config file, AGENTS.md, or similar) first; falls back to asking the user or trying documented stacks in a defined order and reporting which one actually answered. Distinct from `infra-state-verify`, which gates whether a *result* can be trusted as ground truth once you've already queried the right place — this skill decides *where* to query in the first place.
compatibility: Any environment with access to one or more observability stacks (Grafana/Loki/Prometheus MCP or CLI, cloud console, local instance).
---

# Observability Stack Router

A Grafana/Loki/Prometheus query against the wrong stack returns empty results — and empty results look identical whether the host is quiet or the query just missed. Querying cloud Grafana for a Proxmox host whose logs are actually ingested by a local Loki instance produces the same "no data" response as a genuinely healthy, silent host. This skill picks the right stack *before* that query runs, so an empty result means something.

## Trigger condition

Use this before querying logs or metrics for a specific host/service when it is **not already obvious** which stack ingests that target — cloud Grafana/Loki/Prometheus, a local/on-prem instance, or any other documented alternative.

Skip it when the mapping is already known in-session (you already confirmed this host's stack a few turns ago) or the tool/context makes it unambiguous (e.g. only one observability stack exists in this environment). Don't re-run this for every query in a session — once a host's stack is established, reuse that answer until something suggests it's changed.

## Step 1: Check for an explicit mapping

Look for a project-level source of truth before guessing or asking:

- A config file naming which stack covers which hosts/environments (e.g. `observability.yaml`, inventory metadata, a monitoring-targets file)
- `AGENTS.md` or similar project documentation stating the routing (e.g. "Proxmox hosts ship logs to local Loki at `10.x.x.x`; cloud hosts ship to Grafana Cloud")
- Existing infra-as-code (Ansible inventory groups, Terraform tags/labels, Promtail/Alloy scrape configs) that reveals the ingestion path

If a mapping exists and names the target host, use it and move straight to the query — no need to ask or probe further.

## Step 2: No mapping — ask or try in order

If no explicit mapping resolves the target host, do one of:

- **Ask the user directly** which stack covers this host, when the ambiguity can't be resolved cheaply and getting it wrong would waste a round-trip or mislead on host health.
- **Try documented stacks in a defined, sensible order** (e.g. cloud first, then local) when trying is cheap and asking would just slow things down. Only try stacks the project actually documents somewhere — don't invent additional ones to probe.

Pick whichever fits the situation; neither is mandatory over the other.

## Step 3: Report which stack actually answered — never report an empty result as final

**An empty result from the first stack tried is not an answer — it's a reason to try the next one.**

- Report it as: "Queried [stack X] — no data. Trying [stack Y]." Never as a bare "no logs found" until every plausible stack has actually been tried, or the mapping definitively rules the others out.
- Once a stack returns real data, name which one it was in the final answer (e.g. "Found via local Loki, not cloud Grafana") — this is what lets the user and future queries skip straight to the right stack next time.
- If every documented stack comes back empty, say so explicitly and name every stack tried — that is a real "genuinely quiet" result, distinct from a single untried empty response.

## Relationship to infra-state-verify

**`infra-state-verify`** governs whether a result, once obtained, can be trusted and published as ground truth about live infrastructure state. This skill governs something earlier: *which* stack to query in the first place, before any result exists to trust or distrust.

- Use this skill first, to route to the correct stack and get a real result.
- `infra-state-verify` still applies after that — routing to the right stack doesn't by itself confirm the data you see reflects current reality (e.g. ingestion lag, a stale dashboard). Its own "Which observability stack" note covers the same wrong-stack failure mode from the trust-the-result side; this skill is the routing step that happens before that note would even come into play.
