---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-09-04
updated_by: claude
name: confluence-section-edit
description: Make a small, targeted edit to one section of an existing Confluence page — fix a fact, update a link, correct a paragraph — without doc-coauthor's full template/frontmatter overhead or the risk of a full-page rewrite breaking content outside the section touched. Covers locating the target heading, scoping the edit to that section instead of round-tripping the page through markdown, avoiding nested markdown lists inside numbered/bulleted items (a known list-collapse bug), and verifying via re-fetch/diff immediately after every edit (images need live-page verification instead — the read tool always flattens them). Use for "fix this on the wiki page", "quick Confluence correction", "update this section of <page>", "small correction to an existing page", "that fact is wrong on the runbook", or any one-section edit to an existing page. Complements doc-coauthor (new pages/rewrites) and ticket-write-verify's confluence-large-restructuring reference (full reorgs) — this skill covers the lighter single-section case.
compatibility: Requires Confluence MCP (confluence_get_page, confluence_update_page).
---

# Confluence Section Edit

A small, targeted fix to one section of an existing Confluence page doesn't need `doc-coauthor`'s full template/frontmatter workflow. It does need the same care the Confluence API's own quirks require: touch only the target section, never round-trip the whole page through markdown, and verify the result before walking away.

## 1. Identify the target section

Fetch the page in raw storage format — not markdown, see the round-trip warning below: `confluence_get_page(page_id, convert_to_markdown: false)`. Locate the target heading (`h1`/`h2`/`h3`) by its text content.

## 2. Scope the edit to that section, not the whole page

Don't fetch as markdown, edit the markdown, and push a full-page rewrite — Confluence-specific elements (`ac:structured-macro`, `ac:link`/`ri:page`, `<time>` date macros) don't round-trip through markdown reliably, and a full-page rewrite risks touching content outside the section you meant to fix.

1. Parse the fetched storage-format HTML (BeautifulSoup, `html.parser`).
2. Extract the target heading's tag plus its following siblings up to the next heading/`hr` boundary — the same by-index extraction `ticket-write-verify`'s [confluence-large-restructuring.md](../ticket-write-verify/references/confluence-large-restructuring.md) reference uses for full reorgs, just scoped to one section instead of the whole document.
3. Edit only within that extracted slice.
4. Re-insert it at the same position in the original tag list and submit the full reassembled body via `confluence_update_page` — the Confluence API has no partial-page PATCH, so "section-scoped" describes the *edit*, not the submit call, which still carries the whole page.

For a one-line factual correction inside a paragraph (no structural change), a direct text substitution within the fetched storage-format HTML is fine — the extract/reassemble steps above are for edits that touch list, heading, or macro structure, not a single word swap.

## 3. Avoid nested markdown lists inside numbered/bulleted items

A real nested markdown list inside a numbered or bulleted list item is a known breakage point — it can collapse the whole list into plain text on render. Use flowing paragraphs with dash-separated clauses instead of a nested sub-list when a list item needs more than one point.

## 4. Watch for known write corruption

Same identifier/URL/bracket corruption modes as any Confluence write apply here — see `ticket-write-verify`'s known corruption modes table before submitting if the edit touches underscore-heavy identifiers, bracket-style markers, or URLs with underscores.

**Images are a special case — read-side, not write-side.** `confluence_get_page` unconditionally flattens `<ac:image>`/`<ri:attachment>` macros into a bare `<img src="filename">` tag on every fetch, regardless of what's actually stored. A flattened `<img>` in the section you're editing is not proof the image is broken — see `ticket-write-verify`'s [confluence-macros.md](../ticket-write-verify/references/confluence-macros.md) § Image macros before touching it.

## 5. Verify — diff immediately after every edit

Never leave a section edit unverified:

1. Re-fetch the page (`confluence_get_page`, same `convert_to_markdown: false`) immediately after the update call.
2. Compare against what was intended — read the section back for a plain-text edit; run `ticket-write-verify`'s structural-element diff (macro/link/table/date-tag counts) if the edit touched more than a paragraph.
3. If the render is broken (a list collapsed, a macro dropped, a link stripped), fix and re-verify before considering the edit done — don't leave a page live in a broken state on a plan to check later.

**⚠️ Exception: if the edit touched an image macro, step 1's re-fetch is not valid evidence.** `confluence_get_page` always shows a flattened `<img>` tag for images whether or not the macro is actually correct — verify via the live rendered page (screenshot/browser) instead.

## What this skill doesn't do

- New pages, significant rewrites, or anything template-driven — that's `doc-coauthor`.
- Full-document reorganization (moving whole sections, folding an H2 into an H3) — that's `ticket-write-verify`'s [confluence-large-restructuring.md](../ticket-write-verify/references/confluence-large-restructuring.md).
