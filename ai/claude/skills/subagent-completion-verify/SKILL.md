---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: subagent-completion-verify
description: Positively confirm a spawned sub-agent's task is actually finished — commits landed, report actually written, files actually created — before trusting a "completed" status notification. Use whenever any multi-agent orchestrator skill (dev-team, decision-council, or an ad hoc Agent-tool spawn) receives a completion notification and needs to decide whether to proceed or resume the sub-agent. Triggers on "did that agent actually finish", "verify the sub-agent's work", "the notification said completed but I don't see the changes", or before treating any spawned agent's output as ready to build on.
compatibility: Requires git (for commit-based verification) and whatever inspection tools fit the sub-agent's actual deliverable.
---

# Subagent Completion Verify

A task notification's "completed" status describes the harness's view of the turn ending — it does not confirm the sub-agent actually did the work. Treating the two as equivalent is the single most repetitive failure mode in multi-agent orchestration: a spawn returns "completed," the parent proceeds, and the expected artifact (a commit, a file, a report) isn't there.

**Generalizes** the pattern dev-team's own pipeline already applies to its Coder/Tester spawns — this skill exists so other multi-agent orchestrators (`decision-council`, or a one-off `Agent` tool spawn) don't have to re-derive the same check.

## The check

Before trusting a "completed" sub-agent as done, positively verify the artifact its task actually required:

| Sub-agent's job | Verify by |
| --- | --- |
| Wrote code / made a commit | `git log --oneline -1` in the target repo/worktree — is there a new commit matching the described change? |
| Produced a report/summary | Does the returned text actually contain the structured output the prompt asked for (a findings table, a verdict), not just prose acknowledging the task? |
| Created/edited files | Check the files exist and contain the expected content — don't infer from the agent's own claim that it wrote them |
| Ran a multi-step process | Spot-check the last 1–2 steps specifically completed, not just that the agent stopped responding |

## When verification fails

If the expected artifact isn't there, the sub-agent likely stopped short — got pulled into an unrelated tangent, hit a tool error it didn't surface, or genuinely finished but reported prematurely. **Resume it** (`SendMessage` to the same agent, with full context of what's missing) rather than treating "completed" as final and either proceeding without the artifact or re-spawning a duplicate agent from scratch.

Cap resume attempts — repeated resumes without progress point to a defect in the sub-agent's instructions, not a transient hiccup. Two unproductive resumes is a reasonable ceiling before escalating (flag to the user, or fall back to doing the task directly) rather than resuming indefinitely.

## Where this fits in a pipeline

Run this check immediately after receiving a spawned agent's completion notification, before any step downstream depends on its output. In `dev-team`, that's before Manager/Tester trust Coder's diff; in `decision-council`, before synthesis trusts an advisor's verdict.
