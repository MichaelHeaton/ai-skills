---
version: 1.6.0
principles_version: 1.0.0
last_updated: 2026-08-24
updated_by: claude
name: doc-coauthor
description: Co-author work team documentation directly to the live Confluence wiki. Handles the full workflow: doc-type selection, context gathering, section-by-section drafting, and delivery — plus a lighter-weight path for editing already-existing content that skips doc-type selection entirely. Use when writing or updating any team wiki page, runbook, how-to guide, customer guide, or architecture decision record. Triggers on: "write a runbook", "draft a how-to", "create a wiki page", "update the docs for X", "update the wiki", "write an ADR", "document this process", "new Confluence page", "doc for vault", "work team documentation", "update Confluence". A small, targeted correction to an existing page (fixing one fact, one link, one section) should go through the `confluence-section-edit` skill instead of this one; a new page or a significant rewrite goes through this skill.
compatibility: Requires Confluence MCP.
---

# Doc Co-Author

Guide the user through writing a well-structured work team documentation page, delivered directly to Confluence.

*(A staged git-review mode — draft in a repo, sync to a personal wiki space for review, then publish — existed here until 2026-08-24. It depended on the `ces-documentation` repo, which was decommissioned in favor of Confluence as the sole source of truth; the same PR-review-friction objection that killed that repo applies to staging docs in git generally, so this skill no longer offers it. If a future doc needs review before going live, use Confluence's own draft/restricted-page mechanics instead.)*

The workflow: **Doc type → Context → Draft → Test → Deliver**

---

## Before Stage 0 — confirm the edit is still needed

Before gathering context or drafting, ask: *"Given what's changed, does this page/section still need this update — or has the underlying thing already reached its target state?"* This matters more for doc-coauthor than most skills since it writes to a shared/external system — catching a no-op edit here is cheaper than catching it after Stage 1's context gathering has already run. If the user confirms no update is needed, exit cleanly without proceeding further.

---

## Stage 0: Template Selection

**Editing existing content?** If this is a straightforward edit to an already-existing page or section (not authoring something new), skip template selection and frontmatter generation entirely — jump to identifying what's stale vs. accurate in the existing content, then go straight to Stage 2 (Draft). Template selection and frontmatter are for new-page authoring; they add no value to correcting or extending a page that already exists.

**Small enough to be one section?** If the edit is scoped to fixing or updating a single existing section (one fact, one link, one paragraph) rather than reworking multiple sections, use the `confluence-section-edit` skill instead of continuing here — it covers the section-scoped update call, the nested-list breakage gotcha, and the mandatory post-edit diff check that a quick edit needs but this skill's full Stage 0–4 flow doesn't spell out.

Identify the document type:

| Type | Default tier | When to use |
| --- | --- | --- |
| Runbook | oncall | On-call response: symptom → diagnosis → fix → escalate |
| How-to | customer | Step-by-step guide for internal customers consuming a service |
| Customer guide | customer | Broader reference for customers (onboarding, overview) |
| Architecture decision | team | Record a design decision and its tradeoffs |
| Status report | leadership | Narrative update to a manager/stakeholder explaining timeline, scope, or progress on a project |

If the user says "wiki page" or "Confluence page" without a specific type, ask which fits before proceeding. **Status reports and other narrative-with-a-thesis documents route here too** — don't let them get hand-drafted outside this skill just because there's no wiki page or template involved yet; they need the same consistency-audit and humanize stages below, in order, more than any other doc type.

Check `confluence_list_page_templates` / `confluence_get_page_template` for a matching Confluence-native template before structuring the page from scratch. If none fits, structure the page using the type's "when to use" description above as the shape (symptom→diagnosis→fix→escalate for a runbook, etc.).

---

## Stage 1: Context Gathering

Collect everything needed for the content.

**Content questions:**
Ask for an unstructured info dump covering:

- What problem or task does this doc address?
- Triggering scenario (runbooks) or goal (how-tos)
- The steps, decisions, or procedures involved
- Related Confluence pages, Jira tickets, Slack threads, or incidents
- Known edge cases, common mistakes, escalation paths

After the dump, ask 3–5 targeted clarifying questions for remaining gaps.

### Shadow-session mode (optional)

For procedures the user is about to run anyway, offer this as an alternative to the info dump: the user narrates each action as they perform it, in order, without being asked questions mid-stream. Claude only records — no interrupting to ask "why," no filling in a skipped step from assumption. This exists because an expert doing a task from memory reflexively skips steps that feel obvious to them but aren't to a new reader; narrating in real time, in order, surfaces those steps instead of relying on the expert to remember to mention them later.

Hold all clarifying questions until the narration is complete, then ask them normally. Use this mode only when the user invokes it (e.g. "let's do this as a shadow session") — it's slower than a dump-and-clarify pass, so it's not the default.

---

## Stage 2: Draft

### Section by section

Work through the page's sections in order:

1. Draft based on gathered context
2. Show it, ask for feedback
3. Apply edits surgically — never reprint the whole doc
4. Move on when the user is satisfied

### Cascading depth (runbooks & how-tos)

Apply the DRY rule — if something is documented elsewhere in the repo or wiki, link to it rather than restating it. For runbooks and how-tos specifically, that means keeping the step-by-step path lean enough to run under pressure and pushing the "why" out to a separate, reusable concept page rather than growing the runbook.

- Each step (or block of steps that only make sense run together, e.g. a sequence that stacks state) gets **one short why** — a sentence, not a paragraph — plus **at most one link out**. Steps that stack in order share a single link rather than repeating one per step.
- Anything longer than a one-line why belongs on its own concept page (e.g. `Concepts/{topic}.md`), not inline. Give that page a `Referenced from` section listing every runbook/how-to that links into it, so it stays discoverable and gets updated once instead of in N places.
- Don't split a topic into many tiny concept pages — a page nobody edits because it's a paragraph long is worse than one page covering a whole related group of settings/steps. Optimize for "gets kept accurate," not maximum granularity.
- **If the target concept page doesn't exist yet**, do one of two things before moving on — never leave a bare link to nothing and never defer with just "we'll come back to it":
  1. Draft the concept page now, in this session, or
  2. Open a tracking ticket via the `issue-create` skill *(global: ai-skills)*, and put the ticket reference directly at the link site in the doc (e.g. `→ Deep dive: not yet documented — tracked in PROJ-123`) so the gap is visible to the next reader, not just sitting in a ticket queue.

---

## Stage 2.3: Consistency Audit

Run this **before** Stage 2.5 (Humanize) on any doc with a narrative thesis — status reports, ADRs, anything arguing a point rather than just listing steps. Skip it for pure reference material (runbooks, how-tos) that states facts without defending a conclusion.

Spawn a fresh sub-agent with only the draft text and this instruction: *"List every claim that asserts or implies a judgment about cause, blame, scope, or timeline. Flag any pair a skeptical reader could read as contradicting each other. Separately, flag any phrase-family that restates the same pre-emptive rebuttal in more than one place (e.g. 'wasn't a failure,' 'was always the plan,' 'confirmed it, didn't invent it'). Don't flag a repeated correction-disclosure pattern (e.g. '(corrected DATE)') as a rebuttal — that's transparent versioning, not defensiveness."* Fix what it finds before moving on.

Two writing rules this audit enforces, drawn from a real case where an exec summary said "nothing points to a failure" while a later section admitted a scope-trim to "cut scope creep" — a true-but-contradictory-sounding pair a real reader called out directly:

- **No verdict before evidence.** A TL;DR or exec summary that states a conclusion before the reader has seen the facts forces every later fact to be read as either confirming or undermining that verdict — including facts that are just neutral context. State the facts; let the reader conclude. If a summary needs a caveat to avoid contradicting a later section, that's a sign the verdict shouldn't be there at all.
- **State a fact once, where it belongs — never repeat it as a rebuttal elsewhere.** Comparing this project's own reports against three other engineers' recent wiki pages in the same space surfaced the actual pattern: none of theirs defend a thesis or pre-empt criticism anywhere — they state what's true, once, in plain declarative sentences, even in pages substantially longer than the reports getting the "too long" complaint. Length wasn't the team's real objection; a document arguing with an imagined critic across five separate sections was. Cut every sentence whose job is managing the reader's opinion of the writer rather than conveying a fact.

See [references/consistency-audit.md](references/consistency-audit.md) for the full sub-agent prompt and before/after examples.

## Stage 2.5: Humanize

Once the consistency audit above is clean, invoke the `humanizer` skill *(global: ai-skills)* on the draft before reader testing — strips AI-writing tells (puffery, canned phrasing, formatting artifacts) while preserving every step, command, and fact exactly.

**Run this after Stage 2.3, never before.** Humanizer only smooths style — it can't see a logical contradiction, and running it on an unresolved one just makes both contradictory claims read more confidently, which is worse, not better. Run reader testing against the humanized version, not the raw draft.

---

## Stage 3: Reader Testing

Generate 3–5 questions a real reader — an on-call engineer or an internal customer — would bring to this doc. Then test:

- **With sub-agents**: spawn a sub-agent with only the doc content and each question; report what it got right, wrong, or found ambiguous
- **Without sub-agents**: share the questions and ask the user to paste the doc in a fresh Claude window and check the answers

Fix any gaps before delivery.

---

## Stage 4: Deliver

1. If updating an existing page, fetch the current content first to avoid overwriting concurrent edits
2. Use the Confluence MCP tool to create or update the page in the appropriate team wiki space
3. Confirm the page URL to the user when done
