---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: sandbox-exec-delegate
description: Reusable generate-command / user-paste / interpret handoff for when a sandboxed session's kubectl, ssh, or similar tool cannot reach a private/LAN-only target at all — genuine network unreachability, not permission or auth failure, so elevated shell permissions can't fix it. Emits exact copy-paste command(s), waits for pasted output instead of proceeding as if it ran, then interprets that output to continue the task. Trigger on kubectl/ssh/curl to a private LAN host failing identically for any user of this sandbox, "can't reach this host from here", "this is LAN-only", or a live-check needing a target reachable only from the operator's own network. Distinct from `sandbox-blocked-op-router` (triages sandbox-ACL vs. wrong-account gh/git blocks — run first if unclear); use this only once network unreachability is confirmed. `infra-state-verify` documents this pattern for its own reachability fallback; this generalizes it into a standalone, referenceable procedure.
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Requires an operator who can run commands on their own network and paste output back into the conversation.
---

# Sandbox Exec Delegate

A sandboxed session's shell can be blocked from reaching a target in two shapes that look similar but call for different fixes. This skill covers only one of them: the target is on a private/LAN-only network the sandbox's networking has no path to at all, regardless of which permissions the session runs with. Retrying with elevated shell permissions does not help here — the command would fail the same way for any user of this sandbox, not just this session. If that hasn't been confirmed yet, see "Distinguishing the two failure shapes" below.

Per `docs/guides/agent-conventions.md`, don't assert *why* the block exists beyond what's directly observable. Describe the failure by its symptom (times out, connection refused, no route to host, DNS fails to resolve an internal-only name) — not by naming or describing the sandbox's internal network-ACL mechanism, which isn't something this skill can verify from the outside.

## Distinguishing the two failure shapes

- **Permission-restricted but reachable** (`sandbox-blocked-op-router`'s territory) — a `gh`/`git` call fails with an auth or scope error; retrying with elevated permissions, or fixing the account/token in use, can resolve it.
- **Genuinely network-unreachable** (this skill) — a `kubectl`/`ssh`/`curl` call to a private LAN host times out, refuses the connection, or fails DNS resolution for an internal-only hostname, and would fail identically no matter which credentials or permission level ran it.

If it's unclear which shape applies, run `sandbox-blocked-op-router` first — this skill assumes that triage already happened and landed on "not fixable by permissions."

## Step 1 — Detect the block

Confirm the failure is network-reachability, not auth or permissions, before delegating:

- The error is connection-shaped (timeout, connection refused, no route to host, unresolved internal DNS name) rather than credential-shaped (401/403, "permission denied", token/scope errors).
- The target hostname or IP is private/LAN-only — not resolvable or reachable from the public internet.
- Retrying the same command with more elevated permissions would not change the outcome, because the constraint is network topology, not access control.

## Step 2 — Emit the exact command(s)

Give the operator copy-paste-ready command(s), each labeled with what it does. Don't make them guess at flags or fill in blanks.

**Worked example — kubectl:**

> Run this on a machine that can reach the cluster network, and paste back the output:
>
> ```
> kubectl get pods -n default -o wide
> ```
>
> This lists pods in the `default` namespace with their node placement, so I can see which nodes `k3s-node01.internal` is actually running workloads on.

**Worked example — SSH:**

> Run this from your own machine (not from here — this session can't reach that host), and paste back the output:
>
> ```
> ssh admin@k3s-node01.internal "journalctl -u kubelet --since '1 hour ago' --no-pager"
> ```
>
> This pulls the last hour of kubelet logs from `k3s-node01.internal` so I can check for the crash loop pattern.

Use placeholder hostnames like `k3s-node01.internal` in any example or draft that could land in this public repo — never a real internal hostname. See the content-caution rule in this repo's `CLAUDE.md`.

## Step 3 — Wait for the paste, don't proceed as if it ran

The command has not executed until the operator confirms it and pastes the result. Do not:

- Summarize or report an assumed outcome before the paste arrives.
- Continue the original task using placeholder or "expected" output.
- Treat silence as success.

Ask once, clearly, and then stop and wait: "Run the command above and paste the output here — I'll pick up from there."

## Step 4 — Interpret the pasted result and continue

Once the output arrives, treat it as real evidence and resume the original task with it:

- Read the pasted output the same way you would have read the command's own stdout.
- If it's incomplete or ambiguous, ask a targeted follow-up for the specific missing piece — not a fresh broad dump.
- Continue the original task (the diagnosis, the verification, the report) using the interpreted data, rather than restarting from scratch or re-explaining context already established before the block.

## Cross-references

- **`sandbox-blocked-op-router`** — triages whether a blocked `gh`/`git` command is sandbox-ACL (permission-fixable) or wrong-account; run it first when the failure category is unclear.
- **`infra-state-verify`** — documents this same generate-command/paste/interpret pattern as its own fallback for "blocked by network reachability" during a live-state check; this skill is the generalized, standalone version other skills can reference by name instead of re-describing the pattern inline.
