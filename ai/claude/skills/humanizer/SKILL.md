---
version: 1.3.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: humanizer
description: Rewrite an article or draft to strip out AI-writing tells — puffery, canned notability phrasing, overused vocabulary (delve, boasts, testament, underscore, vibrant...), formulaic "Challenges and Future" endings, negative parallelism ("not only X but Y"), rule-of-three lists, and AI-typical formatting — while preserving every fact, citation, and the original meaning exactly, and adding nothing new. Based on Wikipedia's WP:Signs of AI writing field guide. Use when the user says "humanize this", "de-AI this", "make this sound less like AI wrote it", "remove AI writing signs", "this reads like ChatGPT", "strip the AI tells", "clean up the AI-generated tone", or pastes a draft/article asking for a pass to sound more human without changing what it says.
compatibility: none
---

# Humanizer

Rewrite text so it no longer reads as AI-generated, without changing what it says. This is a **style edit, not a content edit**: every fact, number, citation, and claim in the input must survive unchanged in the output. The full pattern list this skill is built from lives in [references/signs-of-ai-writing.md](references/signs-of-ai-writing.md) — read it when a passage doesn't obviously match anything below.

## Non-negotiable constraints

- **Do not add new facts, claims, examples, or citations.** If a sentence feels thin, leave it thin — don't pad it with invented context to make it sound more "human."
- **Do not remove sourced claims or citations** just because the surrounding prose sounds AI-generated. Fix the prose around the citation, not the citation itself.
- **Do not change numbers, names, dates, or attributions.** If you're unsure whether a phrase is a fact or a stylistic flourish, treat it as a fact and leave it alone.
- **Preserve structure the user needs** (section order, wikitext/markup syntax, heading hierarchy) unless the structure itself is an AI tell (see below).
- If a passage is ambiguous — you can't tell whether something is a puffed-up claim or a genuinely sourced one — flag it in your summary rather than silently deleting or rewriting it.
- **Resolving the cut-vs-flag tension:** most puffery carries zero information beyond "this mattered" (*marking a pivotal moment, playing a crucial role*) — cut those silently, no flag needed. Only flag the rarer case where a clause might carry real (if vague) information you can't verify one way or the other, such as an unnamed "other prominent outlets" in a citation-backed sentence. When that happens, keep the underlying claim but strip the inflating adjective (*prominent*, *renowned*), and mention it in your summary rather than guessing.

Meaning and facts are the fixed point. Style is the only thing in motion.

**Run this skill last, after any structural, logical-consistency, or audience fix, never before.** This is a style pass — it isn't designed to catch a contradiction between two sections or a gap where the reader is missing context, and running it on a draft with either unresolved doesn't fix anything; it makes the draft read more fluently and confidently while still being wrong or confusing, which is worse, since polished prose is harder for a reader to catch a problem in than rough prose. If the input is a narrative report or wiki page with a thesis (not just a factual writeup), it should go through `doc-coauthor`'s consistency-audit stage *(global: ai-skills)* first. Any AI-assisted draft — thesis or not — should also go through `doc-audience-check` *(global: ai-skills)* first if it might read like a transcript of the chat that produced it rather than something written for its actual reader.

**For inputs outside `doc-coauthor`'s scope** (Slack messages, one-off comms, non-wiki drafts with no thesis) where a cross-section contradiction still turns up: don't silently rewrite it away. Flag it explicitly instead — the existing "flag ambiguous passages instead of rewriting" constraint has caught real contradictions this way in practice (a self-contradictory "same conclusion" sentence naming opposite positions as identical; a "confirmed" line sitting next to an unresolved ask re-asking the same question), even though catching them isn't this skill's designed job.

## Process

This is the default, full-document process — use it for a fresh draft, or any time you're not sure the lightweight recheck mode below applies.

1. **Read the whole input first.** Don't rewrite sentence-by-sentence on a first pass — AI tells often span multiple sentences (a superficial-analysis clause set up two sentences earlier, a rule-of-three that started the paragraph).
2. **Mark tells before rewriting.** Scan against the checklist below and the reference file. Note which categories show up — this tells you whether the piece needs a light touch or a structural rewrite.
3. **Rewrite section by section**, replacing AI patterns with plain, specific, human phrasing. Prefer the simplest construction that says the same thing.
4. **Re-read for the constraints above.** Diff your rewrite against the original in your head: did any fact move, disappear, or get invented? Did a hedge turn into a certainty, or vice versa?
5. **Return the rewritten text.** Add a short note only if something was ambiguous enough to flag (see constraints) — don't append a changelog by default; a summary of "what I changed" is itself a common AI tell (see § Section summaries below) and adds nothing the diff doesn't already show.

## Lightweight recheck mode (same-session delta)

A repeat pass on a draft this skill already humanized earlier in the same session doesn't need the full process re-run from scratch — that means re-reading the whole document and rebuilding the tell-inventory just to check one added or edited paragraph.

**Recognize this mode when:**

- The draft as a whole already went through a humanizer pass earlier in the session, and
- The caller is asking about a specific, small change since that pass — a paragraph added, a section reworded, one claim rewritten — not a fresh full draft. Phrasing like "recheck this paragraph against the draft I already humanized" or "does this new bit fit the rest" signals it. If the caller instead pastes the whole document again, or you can't tell how much changed, fall back to the full process above — don't guess.

**What changes procedurally:**

1. **Skip re-reading and re-inventorying the whole document.** Don't redo step 1/2 of the full process against text that hasn't changed since the last pass.
2. **Scope the read to the delta plus fit context.** Read the new/changed text itself, plus enough of the surrounding paragraphs (and, for a short piece, the opening) to judge tone and voice — not the entire document.
3. **Check the delta against the same checklist below.** Every pattern in § Checklist still applies; you're narrowing *what* you read, not *what* you check it against.
4. **Use the already-humanized text as the fit reference**, not the checklist in the abstract. The bar is: does the new text read like it was written by the same hand as the surrounding piece — same register, same sentence rhythm, no tell that the rest of the draft had already been scrubbed of?
5. **Apply the same non-negotiable constraints** (no added facts, no removed citations, flag ambiguity rather than rewriting it away) to the delta exactly as you would to a full draft.
6. **Return only the rewritten delta**, unless fixing it requires touching a neighboring sentence for flow — in that case say so briefly, don't silently expand scope back to the whole document.

If the delta itself is large enough that judging fit really requires re-reading the whole piece — a rewritten section, not a paragraph — treat it as a fresh full-process pass instead of forcing it into this mode.

## Checklist: what to remove or rewrite

**Puffery and undue significance.** Cut phrases that inflate a subject's importance without adding information: *stands as a testament to, marked a pivotal moment, played a crucial role, underscores its enduring legacy, set the stage for*. Replace with the plain fact the sentence is actually reporting, or cut the clause if it reports nothing beyond "this mattered."

**Superficial analysis tacked onto facts.** Watch for a factual sentence followed by a present-participle clause that editorializes: *"...creating a lively community," "...further enhancing its significance as a hub of culture."* If the participial clause doesn't come from the source, cut it — don't replace it with a different unsourced claim.

**Canned notability/media-coverage language.** *Has been featured in, profiled in multiple outlets, maintains an active social media presence, independent coverage from* — state what the source actually says (who covered it, when, on what) instead of asserting that coverage-in-general exists.

**Promotional / travel-guide tone.** *Nestled in the heart of, boasts a, rich cultural heritage, vibrant, showcasing.* Rewrite in neutral, descriptive language — say what's there, not how impressive it is.

**Vague attribution and overgeneralization.** *Industry reports suggest, experts argue, observers have cited, several sources* (when one or two are cited). Attribute claims to the specific source named in the citation, or leave attribution as the original text had it — don't invent a stronger consensus than the source supports.

**Overused AI vocabulary.** Words like *delve, boasts, crucial, enduring, fostering, garner, intricate, key, landscape (abstract), meticulous, pivotal, robust, showcase, tapestry, testament, underscore, vibrant, valuable* cluster together in AI text. One instance isn't damning; several in the same passage is. Swap for the plain synonym the sentence actually needs (*wrote* not *authored*, *used* not *utilized*, *died* not *passed away* — see § Signs of human writing).

**Avoidance of "is/are."** AI text swaps plain copulas for *serves as, stands as, functions as, represents, boasts, offers, refers to*. Restore the direct "is/has" construction where it reads naturally — it's a *sign of human writing*, not something to avoid.

**Negative parallelism.** *"Not only X but also Y," "It's not X, it's Y," "no X, no Y, just Z."* These constructions are fine occasionally but formulaic in bulk. Collapse to a single direct statement unless the contrast is genuinely the point being made.

**Rule-of-three overuse.** Three-item lists of adjectives or short parallel phrases used to make a claim look more thorough than it is (*"adjective, adjective, and adjective"*). If the three items aren't independently informative, cut to what's actually supported.

**Formulaic "Challenges and Future Directions" endings.** *"Despite these challenges, X continues to..."* closing paragraphs that restate the subject's importance. Cut the throat-clearing; keep only content-bearing sentences that come from the source.

**Section summaries.** *"In summary," "In conclusion," "Overall, ..."* paragraphs that restate what was just said. Cut them — they add no information.

**Formatting tells.** Title-case section headings (fix to sentence case), excessive/mechanical **boldface**, inline-header bullet lists (`- **Header:** text`) where prose would read better, emoji used as heading decoration, skipped heading levels, thematic breaks (`----`) before every heading, Markdown syntax leaking into wikitext (`**bold**`, `##`, fenced code blocks), stray chatbot artifacts (`:contentReference[...]`, `oai_citation`, `【85†L1-2】`, `utm_source=chatgpt.com` in URLs). Fix the formatting; don't touch the content it wraps.

**Scope this one to article/prose contexts.** "Inline-header bullet lists" and "mechanical boldface" describe encyclopedic or narrative prose (Wikipedia articles, blog posts, reports meant to read as continuous paragraphs) — there, bullets-with-bold-labels are a giveaway that the writer never turned notes into sentences. They do **not** apply to content that is intentionally scannable: a SKILL.md, a runbook, or a comms template (`**Progress**` / `- bullet`, `**Impact:**` labels) uses that structure on purpose, for human skimmability and AI parseability alike — see [docs/guides/formatting.md](../../../../docs/guides/formatting.md) *(global: ai-skills)*. Don't flatten that structure into prose; only clean up sentence-level tells (puffery, vocabulary, hedging) within it.

**Em-dash overuse.** Especially space-surrounded em dashes replacing commas, parentheses, or colons in a formulaic "punched-up" way. This applies to conversational and comms text as much as article prose — if anything, more so, since it's a more common tell in chat/comment-style writing than in encyclopedic articles. Not a strong signal alone; combine with other tells, but don't skip it just because a piece is short or informal.

**Hedging/knowledge-cutoff disclaimers and fabricated absence claims.** *"As of my last update...", "While specific details are limited in available sources...", "not widely documented."* These are usually just noise — cut them rather than "fixing" them into a stronger claim, since you have no way to verify what's actually undocumented.

## What "sounds human" actually looks like

Per the same field guide, don't over-correct into a different kind of stilted prose. Human Wikipedia writing skews toward:

- Plain **is/has** constructions, not "serves as."
- Ordinary synonyms (*wrote, used, tried, died*) over stiffer ones (*authored, utilized, attempted, passed away*).
- Hedges and qualifiers (*perhaps, tends to, largely*) rather than confident absolutes.
- A few wordy-but-natural constructions (*as a result of, in order to*) — these read as AI-avoidant tics only when a piece is scrubbed of every one.

Don't treat "no AI tells" as "terse and clinical." The goal is ordinary, specific, unhedged-or-appropriately-hedged prose — not a different flavor of formula.

## When the input is Wikipedia wikitext specifically

Preserve `[[wikilinks]]`, `{{templates}}`, `<ref>` tags, and category/infobox syntax exactly — these are structural, not stylistic. Only touch them if they contain a literal AI artifact (broken re-use syntax, a hallucinated template, Markdown bleeding into wikitext). If you're not sure a template or parameter is real, leave it as-is rather than guessing — verifying real vs. hallucinated templates is a fact-check task, not this skill's job.

See [references/signs-of-ai-writing.md](references/signs-of-ai-writing.md) for the full pattern list, word bank, and worked before/after examples this checklist condenses.
