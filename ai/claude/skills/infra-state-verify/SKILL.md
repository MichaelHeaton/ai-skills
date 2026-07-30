---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-07-29
updated_by: claude
name: infra-state-verify
description: Gate any published claim about live infrastructure state behind an explicit ground-truth check, so "declared in code" never gets asserted as "confirmed running." Use before publishing a PR description, wiki/Confluence page, Slack/chat message, or status report that says a cluster is running, a feature is enabled in production, a service is deployed, a migration completed, or similar. Trigger on phrases like "is running", "is live", "is enabled in production", "confirm this is deployed", "cluster is up", "shipped to prod", or any time a draft is about to describe live infra state for a teammate or stakeholder to read. Does not apply to answering the user's question conversationally in this session — only to drafting or sending a message meant to reach a teammate or stakeholder outside this session (a Slack DM, PR comment, wiki edit, status report, or similar), or to internal reasoning, scratch notes, and draft thinking that stays in-session.
compatibility: Any repo with Terraform, Kubernetes, Ansible, or a cloud CLI available for live checks.
---

# Infra State Verify

Terraform modules, tfvars, Kubernetes manifests, and Ansible playbooks describe *intent* — what should exist once applied. They are not evidence that it exists. The moment a claim about live infrastructure state leaves the session and lands in a PR description, a wiki page, a chat message, or a status report, a reader will trust it as fact. This skill is a pre-publish gate that stops declared-in-code from being asserted as confirmed-running.

**Scope**: this applies to external/published artifacts a teammate or stakeholder will read and act on. It does not require a live check before every internal mention of infrastructure in conversation, and it does not block reasoning about what a plan or manifest *should* do — only the act of publishing a state claim as settled fact.

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

Live-state claims include: a cluster or service **is running**, a feature **is enabled in production**, a resource **is deployed**, a migration **completed**, something **is live** or **shipped to prod**. If the draft contains language like this, stop before publishing and do the check below.

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

**Ansible**

- The playbook run history/log for the actual host group — did the run reach the relevant task and finish without failure, not just exist in the repo
- A live check on the target host (service status, process check) rather than trusting the playbook's intended end state

**Cloud CLI (AWS/Azure/GCP)**

- A `describe`/`get` call against the actual resource (e.g. `aws eks describe-cluster`, `az aks show`) rather than the IaC source that requested it

**Database migrations**

- Check the migration tracking table or schema-version output against the live database, or the migration tool's `status` command — not just that the migration file exists in the repo

**Feature flags**

- Check the flag service's dashboard/API for the live flag state — not the default or intended value in code

If none of these are available in the moment, say so explicitly in the draft rather than silently asserting the state — see the distinction below.

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
