---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-24
updated_by: claude
name: dev-team
description: Run a ticket through a lightweight multi-agent build pipeline — Architect plans and asks clarifying questions, Coder implements, Tester adversarially checks the diff, Docs updates stale documentation, and a conditional Manager gates on risk. Use when working a ticket end-to-end and you want plan approval before code gets written, or when you say "run this through dev-team", "spin up the dev team on this ticket", "architect this ticket", or "build this with the team". Complements decision-council (which resolves opinions/tradeoffs, not builds) and reuses model-route for per-role model selection. Do NOT use for a quick one-line fix — the Architect step exists to catch ambiguity on real work, not to gate trivial changes.
compatibility: Requires ai/claude/agents/dev-team-coder.md, dev-team-tester.md, dev-team-manager.md, dev-team-docs.md (deployed via `make install-system`)
---

# Dev Team

A 5-role pipeline for working tickets: Architect (this session) → Coder → Tester → Docs → conditional Manager. Built to avoid the token-burn failure mode of an earlier per-ticket agent design, where every invocation reloaded a full agent regardless of ticket size. Only Architect runs by default; Coder/Tester/Docs/Manager are real subagents in `ai/claude/agents/`, spawned via the Agent tool only after plan approval, each scoped to the plan and diff — never the full repo.

This design went through three rounds of `decision-council` review plus a backtest against 20 real merged PRs before landing on 5 roles. Rejected along the way: a Scout role, a Tester/Reviewer split, dedicated Security and SRE roles, and a shared cross-skill agent registry — all deferred as unearned scope until a concrete gap justified them. See the "Known limitations" section below for what the backtest actually found.

## Step 1 — Architect (this session, synchronous)

Read the ticket. Do NOT spawn any agents yet.

1. Scan the repo for the smallest useful context — the files the ticket actually touches, not the whole tree.
2. Ask any clarifying questions you need — up to 3, batched in one turn. Don't proceed on an ambiguous plan just to seem fast.
3. Write a short build plan: files to touch, the approach, and the Coder specialty (`generic`, `terraform`, `db`, `ansible` — default `generic` unless the ticket clearly needs a specialist prompt swap).
4. Present the plan and **stop for explicit approval** before spawning anything. This is the approval gate — Coder/Tester/Docs/Manager never speculatively spin up.

## Step 2 — Coder (background subagent)

Once approved, spawn `dev-team-coder` via the Agent tool with: the approved plan, the ticket text, and the file list from step 1. Nothing else — no full-repo dump.

Route the model via `model-route`'s decision table before spawning (implementation-tier work is `sonnet` by default; only override if the plan itself flags unusually hard cross-cutting reasoning).

## Step 3 — Tester (background subagent, after Coder completes)

Spawn `dev-team-tester` with the diff Coder produced. Tester's job is narrow: break what shipped, and check the one pattern a backtest against real tickets confirmed generic review misses — privileged/binary downloads embedded in template-string or heredoc shell content where integrity verification is optional rather than enforced. Tester reports findings; it does not fix anything.

## Step 4 — Docs (background subagent, deterministic trigger only)

Check the diff against a glob: does it touch `README*`, `docs/**`, or a file containing a public API signature change? If no match, **skip this step entirely** — Docs is conditional on "did relevant files change," not on judgment.

If it matches, spawn `dev-team-docs` with the diff. It runs the `humanizer` skill on any doc text it drafts so documentation stays factually accurate and doesn't read as AI-generated. Output is a **suggested diff, not an auto-commit** — a doc rewritten confidently-but-wrong is worse than a stale one; you review it before it lands.

## Step 5 — Manager (background subagent, conditional)

Spawn `dev-team-manager` only if either is true:

- Tester flagged anything
- The diff crosses a size/risk threshold (touches `auth/`, `payments/`, IAM, or is large relative to the ticket's scope)

Otherwise skip Manager and go straight to your summary — most tickets don't need a fourth agent.

Manager does two things, not one:

1. **Judgment gate** on Tester's findings — pass/fail, not a diplomatic summary. If something's wrong, it says ship/rework/escalate, plainly.
2. **Process verification** — did the review tooling that should have run on this diff actually run (`iac-reviewer` for infra changes, `deep-review` for anything security/perf/architecture-sensitive, `adobe-security-suite` where applicable)? A backtest against 20 real merged PRs found the actual gaps weren't missing capability — they were existing tools never getting invoked before merge. Manager's job includes catching that.

If Manager escalates, it reports back to you and to the Architect step (this session) — not a silent loop. **Hard cap**: after 2 rounds of flag → replan → recode, stop and escalate to the user regardless of Manager's verdict.

## Known limitations (carried from design review, not solved by this pipeline)

- **SCP/policy enforcement invisible at plan time** — infra changes that fail only at `apply` time due to AWS Service Control Policies won't be caught by any review step here. No agent fixes this; it needs an apply-time check or a maintained allowlist, out of scope for this skill.
- **`adobe-security-suite` coverage is account/environment-provisioned**, not a local file — don't assume its coverage exists outside an Adobe-provisioned Claude Code session.
- **Coder specialization is a prompt parameter, not a separate role** — `terraform`/`db`/`ansible` swap the system prompt Coder receives; they are not distinct agent files. Only promote a specialty to its own file once three real specialties are in production use.

## Model routing

Call `model-route` when spawning each subagent rather than trusting a hardcoded tier — the frontmatter `model` field in each `ai/claude/agents/dev-team-*.md` file is a sensible default, not a mandate. Override at spawn time when the ticket's actual complexity warrants it.

## Token verification

Log tokens per role per ticket. This pipeline replaces a system that got replaced *because* it burned tokens — if this one isn't measured, you can't tell if it actually fixed that.
