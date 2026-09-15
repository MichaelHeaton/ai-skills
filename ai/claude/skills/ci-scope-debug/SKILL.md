---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: ci-scope-debug
description: Diagnose a CI PR check that's supposed to be read-only/assertion-only but instead causes side effects (state changes, cert reminting, external calls) or false/flaky failures (timeouts, transient HTTP errors) from touching more than the assertion needs. Covers "check mode should not change state" — a `--check`/`--diff`, `plan`, or dry-run step that mutates state is itself the bug, regardless of what it fails on. Names the assertion the gate must prove, traces what else the command touches, and narrows via tag/target filtering (Ansible `--tags assert`, Terraform `plan -target=`) instead of suppressing the flaky check. Trigger on: "check keeps flaking", "check mode changed something", "CI reminted certs/tokens", "terraform plan times out in CI", "ansible --check did something wrong", "gate too broad", "narrow this CI check", or HTTP 429/307/5xx in a read-only step. Not for real-vs-bot-noise (ci-run-classify) or dispatch allowlist errors (ci-allowlist-hotfix) — this is about blast radius, not classification.
compatibility: Any repo using Ansible, Terraform/OpenTofu, or similar plan/check-mode tooling in CI. No special tools required beyond the IaC CLI already in use.
---

# CI Scope Debug

A CI PR check exists to prove one thing: that a proposed change would pass some assertion. When the check is implemented by running the *entire* underlying tool (a full playbook, a full `terraform plan`) instead of just the part that proves the assertion, the check inherits every side effect and every flaky dependency of the whole run — not just the assertion's own footprint. That mismatch is the bug to find and fix here.

## The signature to recognize

A CI check is in scope for this skill when **both** of the following are true:

1. It is supposed to be read-only, assertion-only, or dry-run in nature (a lint step, a `--check`/`--diff` run, a `plan`, a "does this pass" gate) — not a step that is meant to change anything.
2. It actually does one or both of:
   - **Causes a side effect**: mutates external state, re-issues or re-mints credentials/certificates, calls an external service that has rate limits or side effects of its own, writes to a shared resource.
   - **Produces a false or flaky failure**: intermittent timeouts, transient HTTP errors (429, 307, 5xx), or failures that don't reproduce locally and don't relate to the actual code change under review.

If only (2) is true but the step is genuinely supposed to mutate state (a real deploy, a real apply), this isn't scope creep — it's a different kind of failure. This skill is specifically for the read-only/assertion-only case.

## The core principle: check mode should not change state

A `--check`, `--diff`, `plan`, or dry-run invocation that still mutates external state is a bug in the check itself, independent of whatever error message it happens to surface. Don't debug the HTTP 307 or the timeout first — debug why a step that promises "no changes" caused a change at all.

**Worked example**: An Ansible playbook run with `ansible-playbook --check --diff` against a role that authenticates through Vault re-mints a fresh short-lived SSH certificate on every run, because the login/cert-issuance task isn't gated behind `when: not ansible_check_mode` and Vault treats every login as a new lease. Under normal load this is invisible; under CI's frequency it flakes on Vault's own HTTP 307 (redirect-to-leader) when the cluster is mid-election or under load. The proximate failure looks like "Vault returned 307" — but the actual bug is that a check-mode run is minting real certificates at all. Fixing retry logic around the 307 would treat the symptom; scoping the check to skip cert issuance (or to run only the assertion role/tag that doesn't need a live login) fixes the cause.

## Diagnosis steps

1. **State the assertion precisely.** Write down, in one sentence, what this CI gate is actually supposed to prove — e.g. "the rendered config for role X matches what's expected" or "this Terraform change doesn't unexpectedly touch resource Y." If you can't state it in one sentence, that's itself a sign the check's scope was never deliberately chosen.

2. **List what the invoked command touches beyond that.** Compare the assertion from step 1 against everything the actual invocation exercises:
   - Ansible: a full `ansible-playbook run.yml --check --diff` walks every role and every task in the play — including auth/login tasks, external lookups, and any task not properly guarded for check mode — even though the PR gate only needs one role or tag to hold.
   - Terraform/OpenTofu: a full `terraform plan` refreshes state and evaluates every resource and data source in the configuration, including ones that call external APIs during refresh, even when the PR only changed one module.
   - Generalize the same question to other tools: what does this "read-only" invocation reach out to that has nothing to do with the specific thing under review?

3. **Identify the unnecessary surface as the root cause**, not the transient error it produces. A Vault 307, a Terraform provider API timeout, or a rate-limit response is a symptom of touching more than needed — treat the scope as the bug, not the error code.

4. **Check for missing check-mode guards.** In Ansible specifically, look for tasks that perform real side effects (auth, external API calls, file writes outside a tested path) without a `when: not ansible_check_mode` guard, or that use modules that don't support check mode correctly. A task with real side effects has no business running during a `--check` pass regardless of scope-narrowing.

## Fix pattern: narrow via tags/targets, don't suppress the gate

The fix is to scope the invocation down to just what proves the assertion — not to disable, skip-list, or add blanket retries to the flaky check. Suppressing the check removes the gate's value; narrowing it keeps the value and removes the unnecessary surface.

- **Ansible**: add a tag (e.g. `assert`) to the specific task(s) or role that constitute the actual assertion, and invoke CI with `ansible-playbook run.yml --check --diff --tags assert`. Combine with `when: not ansible_check_mode` guards on any task that has real side effects, so even an accidental broader invocation can't mutate state.
- **Terraform/OpenTofu**: replace a full `terraform plan` with `terraform plan -target=<resource_or_module>` scoped to the resource(s) the PR actually changed, or split the assertion into its own smaller root module / workspace that doesn't include unrelated resources with external side effects during refresh.
- **Other tools, same pattern**: look for the tool's own equivalent of a tag/target/scope flag — a linter's path filter, a test runner's suite/tag selector, a build tool's target selection — and use it to shrink the invocation to the assertion's actual footprint. The generalizable move is always "narrow the invocation to the smallest scope that still proves the assertion," never "catch the error and retry" or "mark the check as allowed to fail."

**Explicitly avoid this shortcut**: disabling the check, adding it to a skip-list, marking it `continue-on-error`, or wrapping it in a blanket retry loop. Any of these makes the flakiness go away without fixing the scope problem — the gate stops providing real signal, and the underlying side effect (e.g. cert reminting) keeps happening on every run, just silently.

## Verification: confirm the assertion still catches real failures

After narrowing scope, deliberately break the thing the check is supposed to catch and confirm the narrowed invocation still fails on it. A check narrowed so far that it no longer exercises the assertion path at all is a no-op wearing the old check's name — worse than the original broad-but-flaky version, because it now provides false confidence instead of occasional noise.

- Ansible: temporarily introduce a config drift in the tagged role/task and confirm `--tags assert` still surfaces it in `--diff` output.
- Terraform: temporarily change the targeted resource's configuration and confirm `plan -target=<resource>` still shows the expected diff.
- Re-run the narrowed check several times under normal CI conditions to confirm the flake/side-effect is actually gone, not just less frequent.

## Related skills

- **ci-run-classify** — classifies whether an already-failing run is a real regression, bot noise, or an empty job. Use it first if you're not yet sure the failure is real; use this skill once you've confirmed the failure (or side effect) traces back to an over-broad check.
- **ci-allowlist-hotfix** — fixes a `workflow_dispatch` input rejected by a `type: choice` allowlist. Unrelated to check scope; it's about dispatch input validation, not blast radius.
- **iac-triage** — general SRE/IaC investigation mode and evidence ordering. Use for broader debugging; this skill is specifically for the "check mode caused a side effect or false failure" pattern.
