---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: infra-rehearsal-session
description: "Structured, checkpointed investigation for hands-on infra troubleshooting — covers both multi-day infra rebuild/migration rehearsals and a single long session working a live incident end-to-end, diagnosing failures against live CLI/Terraform/log output and testing hypotheses before committing to a fix (e.g. 'transit gateway or VPC peering issue?'). Keeps a running plan doc in sync, gates live-system changes behind the IaC path (git → PR → Terraform) with query/describe/lookup always allowed, and hands validated findings to dev-team once confirmed. Use when starting a multi-day infra rehearsal/migration session, when working a live incident hypothesis-by-hypothesis in one sitting (a chain of related failures, each needing its own tested theory before a fix), pasting Terraform/CLI/log output for diagnosis, or saying 'rehearse this migration', 'infra rehearsal session', 'troubleshoot this cluster rebuild'. Complements dev-team, iac-triage, incident-capture (post-mortem after resolution), decision-council."
---

# Infra Rehearsal Session

Structured, checkpoint-driven mode for hands-on infra rebuild/migration rehearsal work. The artifact isn't a diff — it's a sequence of verified operational states plus a running plan doc, spanning however many sittings it takes.

## Step 1 — Start the plan doc

Create (or open, if resuming) a plan doc on a working branch: `docs/ops/<slug>-rehearsal.md`. Commit it at every checkpoint so it survives across sittings and machines — this is what makes the session resumable, not memory.

Sections to maintain:

- **Goal** — what problem this rehearsal is solving
- **Verified so far** — what's been confirmed true, with how
- **Ruled out** — hypotheses tested and disproven, with why (don't retest these)
- **Blocked on** — what's stopping forward progress right now
- **Decisions made** — each decision plus the reasoning, in the order made
- **Next resume point** — the concrete next action, written for a cold start

**Resuming a session:** read "Next resume point" first, before doing anything else.

## Step 2 — Investigate: hypothesis before action

For each open question, form a hypothesis, then run the cheapest test that would confirm or rule it out — don't reach for the expensive/risky test first. This is the core discipline this skill exists to enforce: test-before-build, not build-then-discover-it-was-wrong.

Example of the failure mode this prevents: assuming a transit gateway was the missing piece, when testing against the actual routing in other repos would have shown VPC peering was the real fix. The cost of the wrong assumption is cheap during investigation and expensive after code is written against it.

## Step 3 — The IaC gate (run before every state-changing action)

Before running any command that would alter live infra or system state, stop and classify it:

- **Query / describe / lookup / read-only** — proceed freely, no gate. This is the default mode for the entire rehearsal.
- **A change** — it goes through the standard path: git repo → PR → Terraform deploy. Do not run it directly against the live system, even temporarily "to check."
- **Explicit live exception** — only when the user asks for a direct/no-ops change against this specific instance right now. Say out loud that this is a one-off exception, not something the rehearsal defaults to.

This checkpoint applies every time a state-changing action comes up, not just once at session start — the gate doesn't wear off partway through a long session.

## Step 4 — Update the plan doc after every checkpoint

After each test run, hypothesis confirmed or ruled out, or decision made, update the plan doc in the same pass. A plan doc that drifts from what's actually been verified is worse than no plan doc — the next resume (by you or another session) trusts it at face value.

## Step 5 — Hand off sub-tasks as they come up

Don't solve everything inside this skill — route to the specialist:

- Gap or follow-up discovered mid-rehearsal that needs its own ticket → `issue-create`
- A single high-stakes fork in the approach worth pressure-testing → `decision-council`
- An actual code/config change ready to land → `git-ops` (and `agent-md-sync` if it touches component docs)

## Step 6 — Hand off to dev-team

Once a hypothesis is validated and the actual fix is confirmed — a defendable answer to "what's actually wrong and what fixes it," not just "resolved enough to keep going" — stop and propose the handoff. Present the plan doc's Verified/Decisions sections and ask: "Ready to hand this to dev-team to architect and build?"

Don't auto-invoke `dev-team`. Confirming a diagnosis and deciding to build against it are different decisions, and the second one deserves its own explicit go-ahead.

## Output format

Checkpoint updates are short: what was tested, what it showed, what's next — not a full report every time. Save the full narrative for the plan doc; keep in-conversation updates scannable.
