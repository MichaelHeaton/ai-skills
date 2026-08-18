---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-18
updated_by: claude
---

# Consistency audit

Origin: a real manager status report whose TL;DR said "nothing here points to a scoping or execution failure," while a later section admitted an MVP scope-trim was done "specifically to cut scope creep." Not strictly a logical contradiction — you can trim scope creep without it being an execution *failure* — but juxtaposed with no bridging sentence, a real reader (the manager it was written for) read it as "first you said no scope problem, then you admitted there was one." A decision council convened on this case unanimously converged on one root cause: the document was serving three audiences at once (a manager wanting a verdict, a team wanting "what do I do," a future reader wanting atomic facts) and mixing persuasion with record-keeping in the same paragraphs. The fix isn't a smarter contradiction-detector — it's not writing the persuasion in the first place.

## The sub-agent prompt

Spawn with only the draft text (no conversation context, no author intent) — a fresh read catches what a familiar one skims past:

```
List every claim in this document that asserts or implies a judgment about
cause, blame, scope, or timeline (e.g. "this wasn't a failure," "the plan
never changed," "X confirmed the order, it didn't invent it").

For each one, note which section it's in.

Then flag any pair where a skeptical reader could read the two claims as
contradicting each other, even if they're technically compatible.

Separately, flag any phrase-family that appears more than once making
essentially the same pre-emptive rebuttal in different words. Do not flag
a repeated correction-disclosure pattern (e.g. "(corrected 2026-08-14)",
"previously believed X, actually Y") as a rebuttal — that is transparent
versioning, not defensiveness, and should stay.
```

Fix everything it surfaces before running `humanizer` (see SKILL.md Stage 2.5 for why the order matters).

## Two rules, with real before/after

### No verdict before evidence

**Before** (verdict-first):
> Nothing here points to a scoping or execution failure — this has been inherently serial infrastructure work with continuous, real output.

A reader who hasn't seen the evidence yet is being told how to feel about it in advance. Every fact that follows now gets read as either confirming or undermining that verdict — including facts that are just neutral context, like the MVP scope-trim three paragraphs later. That's what created the perceived contradiction: the verdict closed the case before the scope-trim fact arrived to complicate it.

**After** (facts first, let the reader conclude):
> Q1 2026 shipped on schedule. What's taken the seven months since is a networking prerequisite that didn't clear until late May, five environments' worth of one-time setup, and a deliberate MVP scope-trim on 2026-07-21 to ship the core rollout instead of continuing to expand the epic.

No verdict is asserted. The scope-trim is stated plainly, in the same breath as the other causes, with no defensiveness — and no later section can contradict a conclusion that was never claimed.

### State a fact once, not as a recurring rebuttal

**Before** (same point defended three separate times, in three sections):
>
> - "...mirroring how we already stage CMR upgrades today (dev clusters before prod)."
> - "...the ClickOps-discovery pattern above confirmed why that staged order matters; it didn't invent it."
> - "Test, then dev, then prod was always the migration order... only the test stage has tickets so far... because dev and prod don't need detailed scoping until test proves out."

Three restatements of "this order was planned, not improvised" read as protesting too much — the repetition itself signals defensiveness even though each individual sentence is true.

**After** (stated once, where it belongs):
> Migration follows a test → dev → prod order, matching the existing CMR upgrade pattern. Only the test stage has tickets so far; dev and prod get scoped once test proves out.

One statement, in the section about migration sequencing. If a reader wants to know *why* that order matters, that's a link to the ClickOps-discovery section — not a restatement.

## Don't flag: transparent correction-disclosure

A dry run against a different, mostly-reference project wiki page (an architecture/turnover doc, not a narrative report) surfaced a real false positive from the rule above: the page carried three separate `(corrected 2026-08-14)` / `(corrected 2026-07-15)` tags on status entries that had changed since first written. The audit flagged this as the same "repeated pre-emptive rebuttal" pattern as the original manager-report case.

It isn't. `(corrected DATE)` openly tells the reader a claim changed and when — the opposite of defending a position across multiple sections. Two real catches on that same page (a claim of "confirmed working end-to-end" that was only proven on one of several environments, and a blame-deflecting "not a Vault-side issue" sitting next to evidence the Vault side had just been fixed) were genuine wins from the same audit pass. The lesson isn't "the audit doesn't work" — it's that the rule needs to distinguish *disclosing a change* from *rebutting a criticism*. Keep disclosure. Cut rebuttal.

## Why length wasn't the actual problem

Comparing this pattern against three other engineers' recent wiki pages in the same space (an architecture reference, a migration-planning doc, an onboarding/reference page) found none of them defend a thesis anywhere. They're often *longer* than the reports getting the "too long" complaint — one runs to twelve sections of dense technical reference — but nobody flagged them as too long, because they never argue with an imagined critic. They state what's true, once, in plain declarative sentences, and let a reader who needs the detail scan to the section they need. A reference doc can be long. A narrative arguing with itself across five sections cannot be short enough to fix the actual complaint.
