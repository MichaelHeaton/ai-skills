---
version: 1.4.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: doc-coauthor
description: Co-author work team documentation — either directly to the live Confluence wiki or staged through the git repo for team review. Handles the full workflow: template selection, context gathering, section-by-section drafting, frontmatter generation, and delivery — plus a lighter-weight path for editing already-existing content that skips template/frontmatter entirely. Use when writing or updating any team wiki page, runbook, how-to guide, customer guide, or architecture decision record. Triggers on: "write a runbook", "draft a how-to", "create a wiki page", "update the docs for X", "update the wiki", "write an ADR", "document this process", "new Confluence page", "doc for vault", "work team documentation", "update Confluence". A small, targeted correction to an existing page (fixing one fact, one link, one section) should go through the `confluence-section-edit` skill instead of this one; a new page or a significant rewrite goes through this skill.
compatibility: Live mode requires Confluence MCP. Staged mode requires ${repos.work_docs} (local.json) to be cloned — run repo-setup if missing.
---

# Doc Co-Author

Guide the user through writing a well-structured work team documentation page. Two delivery modes are supported — ask which one applies before starting:

---

## Delivery mode

**Live** — Write directly to Confluence via MCP tools. Use for quick updates to existing pages, minor edits, or when the user wants the change live immediately without a review cycle.

**Staged** — Write a Markdown file into `${repos.work_docs} (local.json)`, commit it, and sync to the personal wiki space (`~${CONFLUENCE_USER}`) for team review before it goes to the production wiki space. Use for new pages, significant rewrites, or anything that benefits from team eyes before publishing.

If the repo isn't available for staged mode, suggest running `/repo-setup` first.

For staged mode: read `${repos.work_docs} (local.json)/CLAUDE.md` — it has the repo structure, frontmatter schema, content tier definitions, DRY rules, and service directory list.

The workflow is the same for both modes: **Template → Context → Draft → Test → Deliver**

---

## Before Stage 0 — confirm the edit is still needed

Before gathering context or drafting, ask: *"Given what's changed, does this page/section still need this update — or has the underlying thing already reached its target state?"* This matters more for doc-coauthor than most skills since it writes to a shared/external system — catching a no-op edit here is cheaper than catching it after Stage 1's context gathering has already run. If the user confirms no update is needed, exit cleanly without proceeding further.

---

## Stage 0: Template Selection

**Editing existing content?** If this is a straightforward edit to an already-existing page or section (not authoring something new), skip template selection and frontmatter generation entirely — jump to identifying what's stale vs. accurate in the existing content, then go straight to Stage 2 (Draft). Template selection and frontmatter are for new-page authoring; they add no value to correcting or extending a page that already exists.

**Small enough to be one section?** If the edit is scoped to fixing or updating a single existing section (one fact, one link, one paragraph) rather than reworking multiple sections, use the `confluence-section-edit` skill instead of continuing here — it covers the section-scoped update call, the nested-list breakage gotcha, and the mandatory post-edit diff check that a quick edit needs but this skill's full Stage 0–4 flow doesn't spell out.

Identify the document type:

| Type | Template | Default tier | When to use |
| --- | --- | --- | --- |
| Runbook | `templates/runbook.md` | oncall | On-call response: symptom → diagnosis → fix → escalate |
| How-to | `templates/how-to.md` | customer | Step-by-step guide for internal customers consuming a service |
| Customer guide | `templates/customer-guide.md` | customer | Broader reference for customers (onboarding, overview) |
| Architecture decision | `templates/architecture-decision.md` | team | Record a design decision and its tradeoffs |

If the user says "wiki page" or "Confluence page" without a specific type, ask which fits before proceeding.

For staged mode: read the chosen template from `${repos.work_docs} (local.json)/templates/`.
For live mode: use the same structure but deliver as Confluence content.

---

## Stage 1: Context Gathering

Collect everything needed for frontmatter and content.

**Frontmatter fields** (staged mode — all required):

- `title` — page title
- `service` — service slug (vault, teleport, cyberark, emissary, hubble, etc.)
- `tier` — one or more of: `team`, `oncall`, `customer`
- `audience` — team, oncall, customer, internal, etc.
- `confluence_page_id` — existing page ID if updating; empty string if new
- `owner` — from local.json or user input
- `sherlock` — true for customer/oncall content, false for team-only

**Content questions** (both modes):
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

### Frontmatter (staged mode only)

Generate the complete frontmatter block first and show it for confirmation — errors in frontmatter break the sync pipeline. Use today's date for `last_reviewed`. Use `wiki_tree: []` for new pages.

### Section by section (both modes)

Work through template sections in order:

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

### Filename (staged mode only)

Lowercase, hyphenated, descriptive. Examples: `approle-cidr-binding-mismatch.md`, `how-to-use-kv2-secrets.md`

---

## Stage 2.5: Humanize

Once the full draft is assembled, invoke the `humanizer` skill *(global: ai-skills)* on it before reader testing — strips AI-writing tells (puffery, canned phrasing, formatting artifacts) while preserving every step, command, and fact exactly. Run reader testing against the humanized version, not the raw draft.

---

## Stage 3: Reader Testing

Generate 3–5 questions a real reader — an on-call engineer or an internal customer — would bring to this doc. Then test:

- **With sub-agents**: spawn a sub-agent with only the doc content and each question; report what it got right, wrong, or found ambiguous
- **Without sub-agents**: share the questions and ask the user to paste the doc in a fresh Claude window and check the answers

Fix any gaps before delivery.

---

## Stage 4: Deliver

### Staged mode

1. Write to `${repos.work_docs} (local.json)/services/{service}/{filename}.md`
2. Remind the user to `git commit` and push
3. To share with the team for review, sync to the personal wiki space:

   ```python
   mcp__atlassian__confluence_create_page(
       space_key="~${CONFLUENCE_USER}",
       title="[DRAFT FOR REVIEW] {title}",
       content=<markdown content>,
       content_format="markdown"
   )
   ```

4. Share the personal wiki URL with the team for async feedback
5. Once approved, update `confluence_page_id` in frontmatter and note that the sync pipeline will push to the production wiki space

### Live mode

1. If updating an existing page, fetch the current content first to avoid overwriting concurrent edits
2. Use the Confluence MCP tool to create or update the page in the appropriate team wiki space
3. Confirm the page URL to the user when done
