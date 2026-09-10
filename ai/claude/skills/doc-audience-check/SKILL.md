---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: doc-audience-check
description: Check a drafted wiki page, runbook, or doc for audience-context leakage — it reads like an explanation aimed at the person who asked the questions, not the actual reader. Catches conversational asides answering unstated questions, tools/people/projects named with zero introduction, sections ordered by chat history instead of reader need, assumed shared context, and claims stated as fact with no visible evidence. Different from `humanizer` (AI vocabulary/formatting tells) and doc-coauthor's reader-testing (content completeness) — this one uses a fresh sub-agent with zero chat history to cold-read the draft, since the author can't see their own gaps. Use before publishing any AI-assisted doc, when feedback says a page explains to the writer instead of the reader, when AI text sounds more confident than verified, or on: "audience check this", "cold-read this doc", "check for context leaks", "this reads like a conversation", "does this claim have evidence behind it".
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Uses a fresh sub-agent for the cold-read step where sub-agents are available; falls back to a manual context-suppressed reread otherwise.
---

# Doc Audience Check

Catch the gap between "I know what I meant" and "a stranger can tell what I meant." A doc built by chatting with an AI often inherits the shape of that conversation — it answers the questions that got asked, in the order they got asked, with the shorthand two people in a chat naturally fall into. None of that is visible to the person who was in the chat, because they already have the missing context loaded in their head. It's very visible to everyone else.

This is a **content/audience edit, not a style edit** (that's `humanizer` *(global: ai-skills)*) and not a completeness check (that's doc-coauthor's Stage 3 reader-testing). It fixes exactly one thing: does this page make sense to someone who was never in the room?

## Why self-review doesn't catch this

You cannot spot a missing-context gap by rereading your own draft — the context isn't missing *to you*. The fix isn't "read more carefully," it's "get a read from someone who genuinely lacks the context you have." That's why the core step below is a fresh sub-agent given only the draft text, not the conversation that produced it: it's the closest thing to putting the doc in front of a real stranger before a real stranger has to.

## Process

1. **Establish the audience**, if it isn't obvious from the doc's location or the request: who lands on this page cold, and what can you safely assume they already know (the product name, maybe) versus what needs explaining (an internal codename, a related tool, why a caveat exists)?

2. **Get a genuinely fresh read.** Spawn a sub-agent with *only* the draft text — no session history, no back-story about how it was written — and this instruction:

   > "You are reading this page for the first time, with no other context. List: (a) any sentence that seems to answer a question you were never asked, (b) any named person, tool, or project mentioned with no explanation of what it is, (c) any point where you'd have to guess what came before to make sense of the sentence, (d) whether the opening actually tells you what this page is and why you'd be reading it, (e) any claim stated as settled fact where the draft itself shows no check, source, or evidence behind it."

   If sub-agents aren't available in this environment, do this manually as a *separate* pass: reread the draft while deliberately not supplying anything you know from the conversation that produced it — judge only the words on the page, the way a search hit or a shared link would land for someone else.

3. **Convert each flag into a fix**, per the checklist below. Prefer cutting over explaining when the aside adds nothing; add the missing sentence of context when the reference is actually useful; ask the user directly rather than guess when you can't tell what's missing — inventing an explanation is worse than flagging the gap.

4. **Structural pass.** Confirm the page opens with orientation — what this is and why the reader is here — before any caveat or warning. A caveat placed first only makes sense to someone who already knows what it's a caveat *about*.

5. **Return the fixed draft, plus a short list of what you changed and why.** Unlike `humanizer` (which suppresses a changelog on purpose), keep this one — the goal here includes helping the person recognize the pattern next time, not just handing back a clean page.

## Checklist: what counts as a leak

**Conversational residue.** A sentence that only makes sense as a reply to something — a warning, a "to be clear," a "not the X you're thinking of" — but the reader never asked the implicit question. Cut it, or turn it into a real statement: say what the thing *is*, don't just deny what someone might have assumed about it.

**Unintroduced references.** A name — another tool, a person, a past project — dropped with no explanation because it only came up in the chat that produced the draft. Either explain it in the same sentence (what it is, why it's relevant) or remove the name and state the underlying property instead ("unlike some similar tools, this one has no separate web portal" rather than naming the other tool and assuming the reader knows what it does).

**Q&A-order structure.** Sections that follow the order questions got asked rather than what a reader needs first (what this is → why it matters → how to use it → edge cases). Reorder for the reader, not for the history of how the draft was assembled.

**Assumed shared context.** Acronyms, internal jargon, "as mentioned," "as discussed" — anything that leans on a conversation the reader wasn't part of. Spell it out or cut the reference.

**Missing orientation.** No sentence near the top establishing what the page is and who it's for. A reader who lands here from a search or a link should not have to infer the topic from context clues three paragraphs in.

**Confident claims without visible evidence.** A conclusion stated as settled fact with no pointer a reader could check — no log, link, timestamp, or source. AI-drafted text tends to sound authoritative regardless of what was actually verified; the verification (or its absence) needs to be written down, not implied by tone. Add the pointer if the claim was checked; say explicitly that it wasn't if it wasn't ("Sherlock reported X; not independently verified" beats a flat, unqualified claim).

See [references/patterns.md](references/patterns.md) for worked before/after examples of each.

## Non-negotiable constraints

- **Don't invent facts to fill a context gap.** If you can't tell what an unintroduced reference means or why a caveat exists, ask the user — don't guess and write it in as if it were always known.
- **Don't cut a reference just because it's a proper noun.** Naming a real tool or product isn't the problem; naming it with zero explanation is. If the comparison is genuinely useful, keep it — and explain both halves.
- **Preserve technical accuracy and every decision in the doc.** This pass changes what's explained and in what order, never what's true or what was decided.
- **Run this after any logic/consistency fix, before a style pass.** If the doc is going through doc-coauthor's pipeline, this slots in as Stage 2.4 — after Stage 2.3 (Consistency Audit) fixes contradictions, before Stage 2.5 (Humanize) polishes wording, since this stage can add or restructure sentences that would then need the style pass applied to them, not the other way around.

## Relationship to other skills

- **`humanizer`** *(global: ai-skills)* fixes how sentences sound (AI vocabulary, puffery, formatting tells). This skill fixes what's missing or misplaced for the reader. A doc can pass one and fail the other — run both, this one first.
- **`doc-coauthor`**'s Stage 3 (Reader Testing) *(global: ai-skills)* checks whether a doc *answers* the questions a reader would bring to it. This skill checks whether the doc *makes sense on its own terms* to a reader with no shared history with the author — a narrower, earlier check. Use this one on any AI-assisted draft, including pages built outside doc-coauthor's structured flow (e.g. a page written by chatting with an AI assistant and pasting the result), not only ones that went through doc-coauthor's stages.
