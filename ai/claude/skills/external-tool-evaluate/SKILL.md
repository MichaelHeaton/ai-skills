---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: external-tool-evaluate
description: Run a linked external repo, library, or tool through a structured evaluate-then-build loop — decision-council review framed as an adoption question, followed by a manual gate to file any approved recommendations as tickets via issue-create. Use when the user explicitly opens an evaluation of something outside this codebase — "evaluate this repo for adoption", "should we adopt X", "is this worth integrating", "should we build on top of Y instead of writing our own", "worth adopting", "compare this tool against what we have", or pastes an external GitHub/tool URL asking whether to use it. Does NOT auto-invoke dev-team — filing tickets is a separate, explicit step, and building them is a separate step after that. Do NOT use when the input is an existing ticket/issue URL — issue-focus's own Step 2.5 already detects and routes evaluation-shaped tickets; this skill is for starting an evaluation from scratch, before any ticket exists.
compatibility: Requires decision-council and issue-create skills. Uses WebFetch/WebSearch to ground the evaluation in the external repo's actual README, docs, or release notes when the user hasn't already summarized it.
---

# External Tool Evaluate

Formalizes a pattern that's been assembled ad hoc several times (ai-skills#404, #411, #412, #416, #402→#440/#441/#442): someone links an external repo or tool and asks whether it's worth adopting. This skill runs that question through `decision-council`, turns the verdict into a ranked list of concrete candidate actions, and stops at a manual gate before any ticket gets filed or any code gets built.

**Boundary with `issue-focus`:** `issue-focus`'s Step 2.5 detects when a ticket someone is *loading* turns out to be evaluation-shaped (title/body signals like "Evaluate:" or "should we adopt") and routes that ticket to `decision-council` instead of building an AC checklist. This skill is the other direction — the user is *starting* an evaluation directly, with no ticket in play yet. If a ticket already exists for this evaluation, use `issue-focus` on it instead; if `issue-focus` already routed to `decision-council` for a ticket this session, don't also run this skill on the same question. Whichever skill's trigger fires first owns the flow.

---

## Step 1 — Confirm the target and gather grounding

Identify the external repo/tool/library being evaluated and what "adoption" would mean here (a dependency, a pattern to copy, a replacement for something existing, a new skill/subagent built on top of it).

Before framing the question, spend up to a minute grounding it:

- If a URL was given, fetch the README/landing page (WebFetch) for what it actually does, license, maturity, and maintenance activity — don't let advisors guess at this.
- Check whether an origin ticket already exists for "why are we looking at this" (search recent issues if the user references one) — link it in the framing if so.
- Note what in this codebase it would touch or replace, if anything is obvious from a quick grep.

If the target or the adoption question is too vague to frame ("is X any good?" with no context on what it'd be used for), ask one clarifying question before proceeding.

## Step 2 — Frame and run the council

Hand off to `decision-council` with the question framed as an adoption decision:

> Should we adopt/integrate/build on **[tool]** for **[specific use case in this codebase]**? Context: [grounding from Step 1 — what it does, why it's being considered, what it would replace or complement].

Let `decision-council`'s own Step 1.5 decide full vs. lighter pass based on actual stakes — a well-known, low-risk library gets a lighter pass; something that would replace core infrastructure gets the full 13-agent pipeline. Don't hardcode that choice here.

## Step 3 — Turn the verdict into a ranked action list

`decision-council`'s output format (Where Agrees / Where Clashes / Blind Spots / Recommendation / One Thing to Do First) is built for a single decision, not a menu. Tool evaluations often surface several distinct candidate actions at once — the ECC evaluation (#402) produced three: two rejected, one shipped. After the verdict, extract and present the distinct actionable items as a numbered list, each tagged with the council's stance:

```
1. [Adopt] — short description — why the council recommends it
2. [Explore later] — short description — open question that needs more info first
3. [Skip] — short description — why the council recommends against it
```

If the verdict only yields a single yes/no with no sub-items, present that as a single-item list rather than forcing a breakdown that doesn't exist.

## Step 4 — Manual gate: ask before filing anything

Stop here. Ask:

> Which of these do you want filed as tickets? Give me the numbers, or say "none."

For each number the user confirms, invoke `issue-create` — do not call `gh issue create`/`glab issue create`/a ticketing MCP tool directly (see `issue-create`'s own routing rules). Link each new ticket back to the evaluation context (source repo/tool, and the origin ticket if one exists).

**Do not auto-invoke `dev-team`** on any filed ticket, even an "obvious win." Filing the ticket is where this skill's job ends — building it is a separate, explicit decision the user makes when they're ready to work that ticket (e.g. via `issue-focus` or `dev-team` directly).

Declining to file anything is a valid, clean stopping point — say so plainly rather than prompting again.
