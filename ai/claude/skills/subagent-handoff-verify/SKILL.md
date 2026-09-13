---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: subagent-handoff-verify
description: Verify a spawn-then-message-later hand-off actually works before relying on it, instead of assuming a named "Agent Team" pattern (spawn a background subagent, message it again later) resolves in the current environment. Use before any skill spawns a background subagent and plans to resume it via a later message call — confirm the exact handle the launch call returned, and confirm the resume call's target type (agent vs. session) actually matches that handle, before committing to the pattern. Falls back to handling the work directly in the current session (calling the target's own direct-action skill inline, or doing the write yourself) when the check fails or is ambiguous. Triggers on "spawn a background agent and message it later", "Agent Team pattern", "resume the subagent", "SendMessage to the agent", "does the hand-off tool actually work here", or when reviewing/authoring a skill (e.g. vault-support, git-ops, dev-team) that describes launching a named background agent and calling back into it.
compatibility: Cloud-compatible — no local-machine-only paths or tooling. The specific hand-off tools available (an agent-launch/resume mechanism, a session-messaging tool, neither) vary by environment and must be checked at runtime, not assumed.
---

# Subagent Handoff Verify

A skill that spawns a background subagent and plans to message it again later is making two unverified assumptions at once: that a hand-off tool exists at all, and that it targets the same kind of handle the launch call actually returned. Neither assumption is safe to bake into a skill's prose — verify both, every time, before committing to the pattern.

**Motivating precedent**: `vault-support`'s "Agent Team" section instructed launching a subagent by an invented name ("memex") and calling it later via a `SendMessage`-shaped tool. The name didn't match any handle a launch call had actually returned, and the resume attempt used a session-messaging tool against what was really a subagent handle — it failed with "session not found." That failure is specific to that skill's own ad hoc usage, not proof that no hand-off mechanism exists in this class of environment (tracked in #530; updating `vault-support` itself is out of scope here — see that ticket).

## The check

Before relying on spawn-then-message-later, verify two things in order:

1. **Capture the real handle.** A subagent launch call returns its own identifier (e.g. an `agentId`) in the launch result. Use that exact value. Never invent a name or reuse a label from a skill's own prose ("call it back as memex") in place of the launch result's actual returned handle.
2. **Confirm the resume call targets the same kind of handle.** A hand-off/resume tool may address *sessions* (by `session_id`) or *agents* (by the `agentId` a launch call returned) — these are not interchangeable. Check the resume tool's own parameter description or schema for which one it expects, and confirm it matches what you captured in step 1. Do not assume based on the tool's name alone, and do not assert from memory that a mechanism does or does not exist in "this kind of environment" — confirm it against this session's own available tools instead (e.g. via a tool-search/discovery call, if one is available).

If both checks pass, proceed with spawn-then-resume as planned.

## When the check fails or is ambiguous

Fall back to handling the work in the current session rather than blocking on an unverified hand-off:

- **Call the target's own direct-action skill inline** in the current session instead of delegating to a background agent you can't reliably resume.
- **Do the write yourself** — if the subagent's job was a single file edit, commit, or comment, perform it directly rather than spawning and hoping the resume path works.
- **Say so explicitly** rather than silently proceeding as if the hand-off worked — a skill that quietly falls back without noting it will look identical to one that succeeded, until the next session hits the same gap cold.

Never assert a blanket claim like "SendMessage doesn't work here" or "this environment has no agent hand-off" in a skill's own prose — that generalizes one broken usage into an unverified claim about the mechanism itself. Describe the verification procedure (capture the real handle, match the resume target type) instead of a conclusion about tool availability, per the skill-conventions.md rule against asserting unverified internals of named mechanisms.

## Where this fits

Reference this skill from any "Agent Team"-shaped section of another skill (`vault-support`, `git-ops`, `dev-team`, or a one-off `Agent` tool spawn) rather than re-deriving the same two-step check independently. It complements `subagent-completion-verify` (which checks whether a spawned agent actually finished) — this skill checks whether you can reach it again at all before you need that.
