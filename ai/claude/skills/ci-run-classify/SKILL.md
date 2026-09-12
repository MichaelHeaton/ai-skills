---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: ci-run-classify
description: Classify one or more failing CI/Actions runs into real regression, bot/noise, or cancelled/empty-job before treating any of them as a problem worth investigating. Use whenever asked "why did the CI job fail", "did the merge break anything", "is this failure real", or during post-merge-cleanup's own CI-check step when its lighter bot-vs-real heuristic needs the fuller three-bucket treatment — post-merge-cleanup does not currently call into this skill automatically, invoke it yourself when its own check isn't enough. Prevents false investigation driven by an automated dependency-bump/regenerate bot's own PR racing a real merge, or a job that shows failed but never actually ran a meaningful step. Generic across repos — describes bot and branch patterns, not one repo's specific bot names or branch scheme.
compatibility: Requires gh CLI (or equivalent Actions/CI API access) to inspect run metadata and step-level logs. Cloud-compatible — no local-machine-only paths or tooling.
---

# CI Run Classify

A run showing red in a status check is not automatically a real problem. Before spending investigation effort on any failing run, sort it into exactly one bucket — treat only "real regression" as worth digging into.

## The three buckets

1. **Real regression** — ran on the actual target branch (main/master, or the PR branch about to merge), failed on a job with a history of passing, and the failure signature reads as an actual code/infra problem (a real test assertion failure, a real Terraform/OpenTofu plan error, a real build/compile error).
2. **Bot/noise** — triggered by an automated dependency-bump PR, a scheduled/auto-regenerate workflow, or a bot's own PR that raced against a real merge and picked up a stale or now-irrelevant diff. The failure is an artifact of the bot's churn, not a problem with the codebase itself.
3. **Cancelled/empty-job** — shows as failed in the status check but ran zero meaningful steps: cancelled mid-dispatch, a matrix job with no matching entries, or a job skipped because a conditional evaluated false. Nothing executed to actually fail.

## Signals to check, per bucket

Treat these as things to go verify on the actual run, not facts to assume — GitHub Actions' own internal accounting of "why did this show failed" varies by trigger type and workflow config, so confirm against the specific run rather than asserting how the platform behaves in general.

**Branch/target check** (regression vs. the other two):

- Is the run's branch/ref the default branch, or the PR branch that just merged — not a bot-owned or short-lived automation branch?
- Common bot-branch naming patterns to recognize generically (don't hardcode one repo's scheme): a dependency-manager prefix (e.g. `dependabot/`, `renovate/`), a `bot/`, `auto/`, or `automated-` prefix, or a `chore/*-regenerate` / `*-scheduled` suffix.

**Actor/event check** (bot/noise):

- `gh run view <run-id> --json triggeringActor,event,headBranch` (or equivalent) — an actor that is a known automation account/app, or an event of `schedule`, `workflow_dispatch` from a bot identity, or a PR event where the head branch matches a bot pattern above, points at bot/noise.
- A bot's own PR that raced a real merge often shows a diff against a now-stale base — if the PR's base moved after the bot opened it, treat a resulting failure as noise rather than a codebase problem, but confirm by looking at what actually changed in the run's diff rather than assuming.

**Step-level check** (cancelled/empty-job):

- `gh run view <run-id> --log` (or the job's step list) — look for zero steps executed, a `cancelled` conclusion with no step ever starting, or a matrix job whose generated matrix had no entries for this run.
- A `skipped` step count equal to the job's total step count, with none `success`/`failure`, is the same signal by another name.

**History check** (regression vs. everything else):

- Has this exact job passed before on this branch? `gh run list --workflow <name> --branch <branch> --json conclusion,createdAt --limit 5` — a job with no prior green run on this branch is weaker evidence of a regression than one that flipped from passing to failing.
- A real failure signature — an assertion message, a Terraform/OpenTofu plan diff error, a compiler error — in the actual log output is the strongest confirmation; a bot/noise or empty-job run typically has no such signature at all.

## Decision order

Check in this order and stop at the first match — don't run all three checks independently and then adjudicate ties:

1. **Empty-job check first.** If step-level logs show zero meaningful steps executed, classify as cancelled/empty-job regardless of branch or actor — there's no failure content left to attribute to a regression or a bot.
2. **Actor/branch check second.** If the run's branch matches a bot pattern or the triggering actor is an automation identity, classify as bot/noise — unless the failure signature is a real code/infra error that would also affect a genuine merge (rare; treat this as an override only with clear evidence, not a default).
3. **Everything else that ran on the actual target branch with a real failure signature is a real regression.**

## Usage

Invoke this ad-hoc for "why did this job fail" / "did the merge break anything" questions. It also applies during `post-merge-cleanup`'s own CI-check step, which has its own lighter, self-contained bot-vs-real heuristic (a narrower branch-name/zero-job check) — `post-merge-cleanup` does not currently delegate to this skill automatically, so reach for this skill yourself when that step's own check leaves the classification ambiguous, rather than assuming the two are already wired together.

## Report

```
Run <id> (<workflow>, <branch>): BOT/NOISE — triggered by automated
  dependency-bump actor, base moved after PR opened, no real diff error in logs.
Run <id> (<workflow>, <branch>): CANCELLED/EMPTY-JOB — 0 steps executed,
  matrix had no matching entries.
Run <id> (<workflow>, main): REAL REGRESSION — OpenTofu plan error on a job
  that passed on the last 4 runs; investigate before merging further work.
```

Only the real-regression bucket warrants further investigation or blocking a merge. Bot/noise and cancelled/empty-job entries go in the summary for visibility, not as action items.
