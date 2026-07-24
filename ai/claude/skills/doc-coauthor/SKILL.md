---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-07-22
updated_by: claude
name: doc-coauthor
description: Co-author work team documentation — either directly to the live Confluence wiki or staged through the git repo for team review. Handles the full workflow: template selection, context gathering, section-by-section drafting, frontmatter generation, and delivery. Use when writing or updating any team wiki page, runbook, how-to guide, customer guide, or architecture decision record. Triggers on: "write a runbook", "draft a how-to", "create a wiki page", "update the docs for X", "write an ADR", "document this process", "new Confluence page", "doc for vault", "work team documentation", "update Confluence".
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

## Stage 0: Template Selection

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

Apply the DRY rule: if something is documented elsewhere in the repo or wiki, link to it rather than restating it.

### Filename (staged mode only)

Lowercase, hyphenated, descriptive. Examples: `approle-cidr-binding-mismatch.md`, `how-to-use-kv2-secrets.md`

---

## Stage 2.5: Humanize

Once the full draft is assembled, invoke the `humanizer` skill on it before reader testing — strips AI-writing tells (puffery, canned phrasing, formatting artifacts) while preserving every step, command, and fact exactly. Run reader testing against the humanized version, not the raw draft.

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
