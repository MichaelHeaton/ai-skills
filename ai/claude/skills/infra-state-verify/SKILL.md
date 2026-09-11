---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: infra-state-verify
description: Gate any claim about live infrastructure state behind an explicit ground-truth check, so "declared in code" never gets asserted as "confirmed running." Use before publishing a PR description, wiki/Confluence page, Slack/chat message, or status report that says a cluster is running, a feature is enabled in production, a service is deployed, a migration completed, or similar — and also before telling the user in chat that a public-facing production domain or service is live/up/deployed, since that conversational claim can be repeated onward to an external stakeholder. Trigger on phrases like "is running", "is live", "is enabled in production", "confirm this is deployed", "cluster is up", "shipped to prod", or any time a draft or in-session reply is about to describe live infra state that a teammate, stakeholder, or the public could act on. Internal asides stay out of scope: answering the user's question about an internal dashboard, a dev/staging environment, or other non-public infra conversationally still does not require a live check. Only conversational claims about public-facing production infrastructure are gated alongside published artifacts — see "Scope" below for the operational test.
compatibility: Any repo with Terraform, Kubernetes, Ansible, or a cloud CLI available for live checks.
---

# Infra State Verify

Terraform modules, tfvars, Kubernetes manifests, and Ansible playbooks describe *intent* — what should exist once applied. They are not evidence that it exists. The moment a claim about live infrastructure state leaves the session and lands in a PR description, a wiki page, a chat message, or a status report, a reader will trust it as fact. This skill is a pre-publish gate that stops declared-in-code from being asserted as confirmed-running.

**Scope**: this applies to external/published artifacts a teammate or stakeholder will read and act on. It does not require a live check before every internal mention of infrastructure in conversation, and it does not block reasoning about what a plan or manifest *should* do — only the act of publishing a state claim as settled fact.

**Narrowed carve-out — public-facing production infra is gated even in chat.** The conversational carve-out above covers internal asides, not claims about infrastructure the public or an external stakeholder can reach. If a live-state claim is about a public-facing production domain or service, it must go through the same ground-truth check as a published artifact — even when it's said only to the user in this session and never drafted into a PR, wiki, or message.

Apply this operational test before asserting live state conversationally:

- **Is the domain/service publicly reachable?** — a customer, board member, or member of the public can hit it directly (a public website, a production API, a customer-facing app), not just someone with VPN/internal-network access.
- **Would an external stakeholder plausibly act on this claim if repeated to them?** — e.g. a board member telling a parent "the new site is live," a customer being pointed at a URL, a stakeholder reporting status upward.

If either is true, the claim is in scope and needs the same live check as the relevant infra type below before you state it as confirmed — not just an HTTP status code or the fact that a deploy was triggered.

If neither is true — an internal dashboard, a dev/staging environment, informal chatter about infra nobody outside the team can reach — the conversational carve-out still applies as before: describe it without running the full check, since no external party can act on the claim.

## The core distinction

- **Declared in code**: the Terraform module is merged, the tfvars set `enabled = true`, the manifest requests 3 replicas, the plan shows the intended diff.
- **Confirmed running**: the apply actually executed and succeeded, the resource exists in the real state file, the pods are Ready, the endpoint answers, the feature flag is actually on in the live environment.

Code declares intent. Only a live check confirms reality. Never let the first stand in for the second in anything published.

## Trigger condition

Before writing or sending any of the following, check whether it asserts a live-state claim rather than describing what code/config says should happen:

- PR description
- Wiki / Confluence page
- Slack or chat message
- Status report / update
- A conversational reply to the user in-session, **if** it's a live-state claim about public-facing production infrastructure (see the operational test above) — e.g. telling the user a public website or customer-facing service "is live" based on nothing more than an HTTP status check

Live-state claims include: a cluster or service **is running**, a feature **is enabled in production**, a resource **is deployed**, a migration **completed**, something **is live** or **shipped to prod**. If the draft — or, for public-facing prod infra, the in-session reply — contains language like this, stop before publishing or replying and do the check below.

## Required check before asserting live state

Match the check to what's actually being claimed — don't just re-read the source file.

**Terraform**

- `terraform state list` / `terraform show` against the real state file — not the `.tf` source or a stale plan
- Check the CI/CD run history for the apply job specifically: did `apply` run and succeed, not just `plan`
- For a specific resource: `terraform state show <resource>` to confirm it's actually provisioned

**Kubernetes**

- `kubectl get pods -n <namespace>` / `kubectl get nodes` for actual Ready status
- `kubectl rollout status deployment/<name>` to confirm a rollout finished, not just was requested
- A live health/status endpoint or load balancer check to confirm it's serving traffic, not just scheduled

**A green HTTP/blackbox probe does not confirm application-level health.** HTTP 200 only proves the endpoint responded — it doesn't rule out a locked database, a failed auth flow, or a crashed worker returning a 200 with an error payload. When a user reports failures despite a green probe, don't stop at HTTP-green as the verification — add an app-level check: inspect the actual response body/payload, run a DB query count, or exercise the real auth flow.

**Ansible**

- The playbook run history/log for the actual host group — did the run reach the relevant task and finish without failure, not just exist in the repo
- A live check on the target host (service status, process check) rather than trusting the playbook's intended end state

**Containers — capability env vars and device mounts are declared intent, not confirmed-running.** A compose/playbook setting `NVIDIA_VISIBLE_DEVICES` (or a similar capability env var) plus a bind-mounted `/dev` device node claims hardware acceleration is available — it doesn't confirm it. The required check is a live probe of the actual binary/process inside the container (the vendor status tool shows the workload, or the runtime library the workload needs is actually present) — not the presence of the env var or device node alone. Any PR/wiki language claiming hardware acceleration or a device is "enabled" must cite that probe, not the compose declaration.

**Vault SSH CA signing** — if signing fails, document the failure in the draft and ask the operator to paste the journal/dmesg output (or equivalent); don't assert the unverified state as confirmed just because the request was sent.

**Which observability stack** — before querying metrics/logs for a target host, confirm which stack actually ingests it (cloud vs. local) first. An empty result from the wrong stack looks identical to missing data from the right one — treat an empty result as a possible wrong-stack query, not automatically "nothing to report."

**Cloud CLI (AWS/Azure/GCP)**

- A `describe`/`get` call against the actual resource (e.g. `aws eks describe-cluster`, `az aks show`) rather than the IaC source that requested it

**Database migrations**

- Check the migration tracking table or schema-version output against the live database, or the migration tool's `status` command — not just that the migration file exists in the repo

**SQLite/embedded-database restore**

- `kubectl cp` (or any file copy) completing without error is not evidence the restore is valid — the copy succeeding and the database being intact are different claims
- Run `PRAGMA integrity_check` against the restored file and confirm it returns `ok`
- Spot-check row counts on the key tables against a known-good reference (a pre-incident count, or the source backup) before asserting the restore succeeded

**Feature flags**

- Check the flag service's dashboard/API for the live flag state — not the default or intended value in code

**When the required check itself can't run**, the fallback depends on why:

- **Blocked by security controls** (Auto-review denies reading a secret the natural check needs, e.g. an API key for a GraphQL smoke test): substitute a probe that avoids the credential entirely — a DB row count, login-page reachability, or an equivalent non-secret signal — and document which check actually ran in place of the blocked one.
- **Blocked by network reachability** (a sandboxed session's `kubectl`/SSH can't reach a private LAN host): this is a third outcome, distinct from pass/fail — emit the exact command(s) needed, ask the user to run them and paste the output, then interpret the pasted result. A blocked attempt is not itself the ground-truth check; don't improvise a workaround that skips verification instead of handing it off.

If neither substitute is available in the moment either, say so explicitly in the draft rather than silently asserting the state — see the distinction below.

## Distinction in written output

**Bad** (declared-in-code asserted as fact):

> The new EKS cluster is live and serving traffic.

**Good** (honest about what's actually confirmed):

> The EKS cluster module is merged and its Terraform plan was reviewed; confirming actual apply status before reporting it as live.
>
> Confirmed via `kubectl get nodes` — the EKS cluster is live with 3 nodes Ready.

The second form is fine to publish immediately because it names the check performed. The first form is exactly the overclaim this skill exists to catch — it reads as confirmed even though only the code was inspected.

## Why this matters

An overclaim in one artifact tends to propagate — a PR description gets copied into a wiki page, then paraphrased into a status update or chat message, each generation with less context about how uncertain the original claim was. Catching it once at the point of publishing is cheaper than correcting it across every downstream copy.
