---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: infra-assumption-verify
description: Structured pre-scoping checklist for infra-expansion and infra-capacity tickets — runs a fixed investigation order (cert/SAN validity check, DNS record check, ENI/VPC IP-capacity check, repo-code-assumption-vs-live-state check) before writing up scoping findings, replacing ad hoc unordered Explore-subagent spawns. Trigger on "scope this infra expansion", "how much capacity do we have for", "before I write up this cluster/node/subnet expansion ticket", "check if we have room to grow", "pre-scoping check for infra ticket", "verify assumptions before scoping this", or any ticket about expanding cluster nodes, subnets, IP ranges, or certificates where findings will be written up before implementation starts. Sits between impl-preflight (implementation-readiness on a ticket already being coded) and infra-state-verify (gates a claim right before publishing) — this runs earlier, at the scoping/discovery phase, feeding live-state checks directly into what gets written on the ticket.
compatibility: Requires read access to the target infra repos (Terraform/manifests) and either direct or handed-off cloud CLI / DNS / cert-checking tools per cloud-cli-execution-ownership.
---

# Infra Assumption Verify

Scoping an infra-expansion ticket (more cluster nodes, a bigger subnet, a new cert-backed endpoint) by spawning ad hoc Explore subagents in whatever order comes to mind produces inconsistent coverage — one scoping pass checks certs and capacity but skips DNS, another does the reverse. This skill fixes the order so every scoping pass covers the same ground before findings get written up.

**Boundary with related skills** — read this before assuming overlap:

- `impl-preflight` runs once a ticket is already being implemented, checking dependencies and constraints for the *coding* work about to start.
- `infra-state-verify` gates a claim about live infra state right before it's *published* (a PR description, wiki page, status report).
- `infra-assumption-verify` (this skill) runs earlier than both — at the *scoping* stage, before a ticket has an implementation plan or any findings written up at all. Its output feeds directly into what gets written on the ticket, which `infra-state-verify` may later gate again before that write-up is published externally.

## The checklist, run in this order

Run all four checks before writing up findings — skipping one because "it's probably fine" is exactly the ad hoc pattern this skill replaces. If a check is genuinely not applicable to the ticket (e.g. no cert involved), say so explicitly rather than silently omitting it.

### 1. Cert / SAN validity check

- Locate the TLS certificate(s) relevant to the expansion (search infra repos for the cert resource, ACM ARN, or cert-manager `Certificate` object).
- Confirm the cert's SAN list already covers any new hostnames the expansion will introduce, or flag that a SAN update / new cert request is part of the scope.
- Check expiry date — an expansion that will still be live past a near-term expiry needs the renewal noted as a dependency.

### 2. DNS record check

- Confirm DNS records (A/AAAA/CNAME) exist or are planned for any new endpoints the expansion introduces.
- Check for conflicting or stale records occupying the same name.
- Note the DNS zone/provider and who owns record changes if this session can't make them directly.

### 3. ENI / VPC IP-capacity check

- Identify the target subnet(s) and their current available IP count (subnet CIDR size minus AWS-reserved addresses minus in-use ENIs).
- Compare available capacity against what the expansion needs (new nodes × ENIs-per-node, or equivalent for the resource type).
- Flag explicitly if capacity is insufficient — this is often the actual blocker, and catching it here avoids a mid-implementation surprise.

### 4. Repo-code-assumption vs. live-state check

- For each assumption the scoping ticket or its author is relying on (e.g. "the load balancer already points at these nodes," "this subnet is dedicated to this cluster"), check the actual Terraform state or live cloud state, not just the `.tf` file's declared intent — declared and live can diverge.
- Note any divergence found, since it changes what the expansion actually needs to account for.

## Write up findings

Once all four checks are done (or explicitly marked not-applicable), write up the scoping findings in one pass, in the same order as the checklist, so a reader can tell at a glance which checks passed, which found a blocker, and which were skipped and why. Hand off any cloud CLI verification commands per `cloud-cli-execution-ownership` rather than running them directly if that convention is active for the project.

## What this skill is not

- Not an implementation-readiness check — that's `impl-preflight`, which runs once coding is about to start on an already-scoped ticket.
- Not a pre-publish gate — that's `infra-state-verify`, which re-checks a claim right before it goes out in a PR/wiki/status report, potentially re-verifying findings this skill already gathered if enough time has passed.
- Not a replacement for Explore subagents as a mechanism — it fixes their *order and coverage*, not whether subagents are used to run each check.
