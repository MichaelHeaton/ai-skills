---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-08-27
updated_by: claude
---

# Signs of AI writing — full pattern reference

Condensed and adapted from Wikipedia's [WP:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) field guide (CC BY-SA). That page documents patterns observed in real AI-generated Wikipedia edits; this file reorganizes them into a working checklist for rewriting text. Read the source page directly if you need a specific dated example or citation for a pattern.

**How to use this file:** SKILL.md's checklist covers the highest-frequency tells. Come here when a passage feels "off" but doesn't match anything in the main checklist, or when you need the full word bank for a vocabulary-density judgment call.

## 1. Content-level tells

### Undue emphasis on significance, legacy, broader trends

AI writing inflates minor facts into claims about historical importance, cultural legacy, or "broader debates." Watch for a factual sentence followed by a clause claiming it "marked a pivotal moment," "represented a significant shift," or "reflects a broader movement" — when the source doesn't actually make that connection. Also watch for hedged-then-inflated constructions: "Though relatively obscure, X nonetheless represents..." Fix: state the fact; cut the inflation.

### Canned notability / media-coverage emphasis

Listing outlets a subject was "featured in" or asserting "independent coverage" / "active social media presence" as a stand-in for actually describing what the coverage said. Fix: name what the source reports, not the fact that sources exist.

### Superficial analyses

A factual clause followed by a present-participle tail that editorializes about significance, recognition, or impact ("...further enhancing its role as a hub," "...contributing to the broader development of the region"). These are usually synthesis — not present in the cited source. Fix: cut the tail clause rather than replacing it with a different unsourced one.

### Promotional / advertisement language

Travel-guide or press-release register: "nestled in the heart of," "boasts a," "rich cultural heritage," "vibrant," "showcasing," "commitment to." Fix: neutral, specific, descriptive language.

### Vague attribution and overgeneralization

"Industry reports suggest," "experts argue," "several sources" (when the citation list shows one or two). Also: implying a list of examples is non-exhaustive ("such as") when the source gives no indication more exist. Fix: attribute to the specific named source, or match the original's attribution — don't strengthen a claim's apparent consensus.

### Outline-like "Challenges and Future Directions" conclusions

A closing paragraph beginning "Despite its [positive framing], X faces challenges including..." and ending with a vague positive assessment or speculation about future initiatives. This is a rigid formula, not simply the mention of a real challenge. Fix: keep only content that traces to a source; cut the throat-clearing frame.

### Leads that treat a non-proper-noun title as a standalone entity

"Catchment area (health) refers to..." when the article title is a general term, not a proper name. The MOS allows working a title into a natural lead sentence, but AI leads tend to sound stilted doing it. Fix: write the lead the way a knowledgeable person would introduce the topic, not as a dictionary-style "X refers to Y."

## 2. Language and grammar tells

### High density of "AI vocabulary"

No single word is proof by itself — several clustering in one passage is the signal. Words observed across models and eras:

*Additionally (sentence-initial), align with, boasts (meaning "has"), bolstered, crucial, delve, emphasizing, enduring, enhance, fostering, garner, highlight (verb), interplay, intricate/intricacies, key (adjective), landscape (abstract noun), meticulous/meticulously, pivotal, robust, showcase, tapestry (abstract noun), testament, underscore (verb), valuable, vibrant.*

Grok output specifically overuses pseudo-scientific words: *causal, empirical, correlate*, and continues to overuse *underscore*. Different models/eras skew toward different subsets — the point isn't matching an era, it's noticing clustering.

### Avoidance of basic copulas ("is"/"are")

AI text swaps plain "is/has" for "serves as," "stands as," "functions as," "represents," "boasts," "offers," or (in lead sentences) "refers to" — treating the subject as needing an introduction rather than a direct statement. Fix: restore the direct copula where it reads naturally. This is one of the few cases where "sounds more basic" is the correct fix.

### Negative parallelism

"Not only X but also Y," "It's not X, it's Y," "no X, no Y, just Z," and the reversed form "X rather than Y" (especially in Grok output). Occasional use is normal human writing; formulaic repetition across a passage is the tell. Fix: collapse to one direct statement unless the contrast is the actual point being made.

### Rule of three

Adjective-adjective-adjective or short-phrase-short-phrase-and-short-phrase constructions used to make an analysis look more thorough than the source supports. Fix: keep only the items that are independently informative and sourced.

### Lexical diversity / elegant variation

AI text has a strong repetition-penalty tendency: it avoids reusing the same term for the same referent, cycling through synonyms ("the constraints of socialist realism" → "the challenging climate of Soviet artistic constraints" → "state-imposed artistic norms") in ways that read as evasive rather than precise. Fix: it's fine — often better — to reuse the exact same term for the same referent across a passage. Don't introduce variation for its own sake.

## 3. Formatting and style tells

**Scope: article/prose contexts only** (Wikipedia articles, blog posts, reports meant to read as continuous paragraphs). The two structural tells below — inline-header lists and mechanical boldface — describe notes-dressed-up-as-prose, not intentionally scannable formats. A SKILL.md, runbook, or comms template (`**Progress**` / `- bullet`, `**Impact:**` labels) uses that same shape on purpose for skimmability; don't apply this section to it. See [docs/guides/formatting.md](../../../../../docs/guides/formatting.md) *(global: ai-skills)*.

- **Title case headings** ("Impact of Technology and Digitalization") instead of sentence case. Fix to sentence case per MOS.
- **Mechanical overuse of boldface** — bolding every instance of a chosen term "key takeaways" style. Fix: bold only what genuinely needs emphasis, sparingly.
- **Inline-header vertical lists** — `- **Header:** descriptive text` bullets where prose would read better and the structure adds nothing.
- **Em dash overuse**, especially space-surrounded em dashes replacing commas, parentheses, or colons in a formulaic "punched-up" way. More common in AI talk-page/comment text than article prose. Not a strong signal alone — combine with other tells.
- **Emoji used as heading/bullet decoration** (👋, 🌍, 🎯) — almost always a giveaway in comments and user pages; rare but real in article space.
- **Unusual small tables** for content that reads better as prose or belongs in an infobox.
- **Curly quotation marks and apostrophes** (" " ' ') — weak signal alone; common in Chicago-style prose, macOS/iOS smart-quotes, and legitimate citation tools. Only meaningful combined with other tells.
- **Skipped heading levels** (jumping from `==` straight to `===`) — very unlikely in manually formatted text, since it breaks Wikipedia's own accessibility conventions.
- **Thematic breaks before every heading** (`----`) — a Markdown habit bleeding into wikitext.

## 4. Markup and technical artifacts (strong signals — always fix)

These are unambiguous chatbot leftovers, not style choices. Remove them and repair the surrounding syntax without altering the content they wrap:

- **Markdown syntax in wikitext**: `**bold**`, `##Heading`, fenced code blocks (` ```wikitext `), parenthesis-style links `[text](url)` instead of `[url text]`.
- **Broken/garbled wikitext**: malformed category tags, corrupted date strings, mismatched brackets from a failed copy-paste.
- **Chatbot internal formatting bugs**: `:contentReference[oaicite:0]{index=0}`, `oai_citation`, `citeturn0search0` (or similar `turn0(search|image|news|file)N` tokens), `({"attribution":{"attributableIndex":"X-Y"}})`, `[cite: 1]` / `[span_1][start_span]` (Gemini), `<grok-card data-id="...">` / `grok_render_citation_card_json` (Grok), lenticular-bracket citations like `【85†L261-269】` (DeepSeek), `[attached_file:1]` (Perplexity), `:::writing{variant="document" id="12345"}`.
- **UTM/referrer fingerprints in URLs**: `utm_source=chatgpt.com`, `utm_source=openai`, `utm_source=copilot.com`, `referrer=grok.com`.
- **Hallucinated categories or templates** appearing as red links, especially plausible-sounding infobox types or SEO-keyword-shaped categories.
- **Non-existent or unused named references**: `<ref name="x">` declared but never called inline, or called but never defined.

## 5. Citation issues — flag, don't silently fix

These require verification against the actual source, which is a fact-checking task outside this skill's scope. Flag them in your summary rather than guessing:

- Broken external links not found in web archives.
- DOIs or ISBNs that fail checksum, or that resolve to an unrelated article.
- Book citations with no page number, or with a page number that doesn't verify the claim.
- Placeholder text in citation fields: `2025-XX-XX`, `INSERT_SOURCE_URL`, `PASTE_YOUTUBE_VIDEO_URL_HERE`, `SOURCE_PUBLISHER`.
- Access-dates implausibly older than the edit date.

## 6. Communication meant for the user, not the page

Sometimes AI output includes text meant as chat correspondence, accidentally pasted into the content:
"I hope this helps," "Would you like me to...," "Here is a detailed breakdown," "Certainly!," unfilled bracket placeholders (`[Describe the specific section...]`, `[Your Name]`), knowledge-cutoff disclaimers ("As of my last training update...," "specific details are limited in the provided sources"), and submission-statement paragraphs addressed to a reviewer rather than a reader. Fix: delete outright — none of it is article content.

## 7. Signs of human writing (the actual target)

Don't over-correct into a different kind of stilted prose. These are *more* common in human writing, not less, and re-introducing them is often the fix:

- Plain **is/has** constructions ("there is a," "it has a").
- Ordinary synonyms over stiff/euphemistic ones: *wrote* (not authored), *used* (not utilized), *tried* (not attempted), *died* (not passed away), *moved* (not relocated).
- Hedging qualifiers and intensifiers used naturally: *very, perhaps, tends to* — sparingly, where the source itself hedges.
- Wordy-but-natural constructions: *as a result of, in order to, a part of* — fine in isolation; only a tell when a passage has been scrubbed of every one of them in favor of terse fragments.

## 8. Ineffective indicators — do not treat these as tells on their own

Over-fixing on weak signals produces worse prose and risks deleting real content. These are *not* reliable AI markers by themselves:

- Perfect grammar (many humans write cleanly).
- Mixed casual/formal register (common in technical fields, multi-editor pages, neurodivergent writers).
- "Bland" or "robotic" prose in isolation — subjective, and not everyone reads AI-typical prose as robotic.
- "Fancy," academic, or formal vocabulary broadly — only the *specific* word list in §2 is the actual signal.
- A single transition word (*Additionally, Moreover*) — only formulaic sentence-initial clustering matters.
- Missing citations — extremely common in ordinary human-written drafts.
- Curly quotes alone, or correct wikitext alone.

## Working principle

Every fix in this file is a **subtraction or a substitution**, never an addition. If applying a fix would require inventing a new fact, a new source, or a stronger claim than the original supported, don't apply it — leave the sentence plain instead.
