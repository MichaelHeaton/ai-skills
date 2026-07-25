---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-24
updated_by: claude
name: prompt-draft
description: Turn a raw, messy, half-formed idea — a brain dump, rambling voice memo, or vague ask — into a clean task spec, then act on it immediately instead of handing back a prompt to re-paste. Explores the codebase first to resolve anything answerable from context, and hands off to grill-me when real ambiguity remains. Use when the user drops a rough idea and wants it turned into in-session action: "here's a messy idea", "help me turn this into a clear task", "draft a prompt for this", "clean this up into a spec", "I don't really know how to phrase this but...", or a long rambling request that needs organizing before work can start. Do NOT trigger if the plan is already structured (use grill-me directly), the request is already well-specified (just do the work), or the deliverable is a ticket (issue-create/brain-dump), a reusable skill (skill-create), a doc/runbook (doc-coauthor), or an AI-tell-stripping pass (humanizer).
---

# Prompt Draft

Turn the raw input into a clean task spec: the goal, the concrete deliverable, and any constraints or context you can infer from what was said.

If a detail is answerable by exploring the codebase, explore it instead of guessing or asking — the spec should reflect what's actually there, not an assumption.

If real ambiguity remains — a genuine decision branch with no clear default, something exploring the codebase couldn't resolve — don't ask about it here. Hand off directly into `grill-me`'s interrogation instead of drafting your own questions; that's its job, not this skill's.

Once the spec is clear — either immediately, or after `grill-me` resolves the open branches — proceed to do the work from that spec. Don't stop and hand back a written prompt for the user to re-paste; the point of this skill is to skip that step.
