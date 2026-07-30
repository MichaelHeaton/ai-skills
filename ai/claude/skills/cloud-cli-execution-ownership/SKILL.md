---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-07-29
updated_by: claude
name: cloud-cli-execution-ownership
description: Confirms once per project/cloud account whether the user wants cloud CLI commands (aws, gcloud, az, or kubectl pointed at a cloud-managed cluster context) run directly via a shell tool, or handed over for the user to run themselves and paste back output. Prevents a mid-session correction after several commands — including mutating ones — have already run the "wrong" way. Trigger on the first cloud CLI command about to be executed directly in a given project/account scope: any `aws`, `gcloud`, `az` invocation, cloud-context `kubectl` calls, "run this aws command", "let's tag these resources", "update the security group", "check on this in gcloud", "let's apply this via az cli", or any infra session where cloud CLI use is imminent. Do not re-ask within the same project/account scope once cached — but re-ask if the project or active cloud account/region/profile changes.
compatibility: Any session using a shell tool with aws/gcloud/az/kubectl available.
---

# Cloud CLI Execution Ownership

Cloud CLI commands (`aws`, `gcloud`, `az`, and `kubectl` against a cloud-managed cluster context) can mutate real infrastructure. Some users always want to run these themselves — reviewing output before it's acted on — rather than have the assistant execute them directly, even with valid cached credentials. Catch that preference once, before the first command runs, instead of learning it mid-session after several commands already went the "wrong" way.

This skill governs on-prem/local `kubectl` differently: it doesn't count as a cloud CLI trigger, since it carries no cloud-account blast radius.

## When this fires

The first time, within a given project/cloud account scope, that a cloud CLI command is about to be run directly via a shell tool. Not local kubectl, not general shell commands, not anything already covered by the cached answer for the current scope.

## The rule of thumb (read-only vs. everything else)

Don't gate trivial checks — but don't let a single free pass become an unadmitted batch either.

- **A single, clearly read-only command** (`aws sts get-caller-identity`, `gcloud config list`, `az account show`, `kubectl get` against a cloud context) may run once before asking — it carries no mutation risk and asking first would just be noise.
- **Ask before the second cloud CLI call in the current project/account scope, or before any mutating call, whichever comes first.** "Mutating" means create/update/delete/apply/tag/attach/detach/start/stop/scale or anything else that changes state. A batch of read-only calls still counts as more than one — ask before the second one, don't let a run of "just checking" calls slide through un-confirmed.

If the very first cloud CLI call is already mutating, ask before running it — don't spend the one free pass on a mutation.

## The question to ask

Ask once, with labeled options, not open-ended:

> This project is about to run `aws`/`gcloud`/`az` commands directly. Do you want these run directly, or would you prefer to run them yourself and paste back the output?
>
> 1. **Direct execution** — I run these via the shell tool as needed.
> 2. **Hand over to you** — I give you the exact command to run, you paste back the output.

Wait for a clear answer before proceeding with anything beyond the one allowed read-only pass.

## Caching the answer

Once answered, treat it as settled for the rest of this project/cloud account — don't ask again for subsequent commands, subsequent tools, or read-only vs. mutating distinctions within that scope. If the working directory changes to a different project, or the active cloud account/region/profile changes, treat that as a new scope and ask again before the first cloud CLI call in it.

This scope boundary is judgment, not detection logic — the same as the on-prem-vs-cloud `kubectl` distinction above. A long session that hops from one project or account to another needs a fresh ask each time it hops; a session that stays in one project/account the whole time needs exactly one.

If the user's answer sounds like a durable, cross-project preference ("I always want to run these myself"), say so and suggest saving it to their personal config or memory — but don't build that persistence mechanism as part of this skill. Saving a durable preference is a separate, optional follow-up, not something this skill does automatically.

## What this skill is not

- Not a hard gate on every cloud CLI command — only the first one (or the point where the rule of thumb above triggers) needs the ask.
- Not a blocker for on-prem/local Kubernetes work.
- Not a preference-persistence system — caching is scoped to the current project/cloud account only, unless the user explicitly asks to save it durably.
