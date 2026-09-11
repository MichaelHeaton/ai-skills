---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: confluence-section-edit
description: Make a small, targeted edit to one section of an existing Confluence page — fix a fact, update a link, correct a paragraph — without doc-coauthor's full template/frontmatter overhead or the risk of a full-page rewrite breaking content outside the section touched. Covers locating the target heading, scoping the edit to that section instead of round-tripping the page through markdown, avoiding nested markdown lists inside numbered/bulleted items (a known list-collapse bug), and verifying via re-fetch/diff immediately after every edit (images need live-page verification instead — the read tool always flattens them). Use for "fix this on the wiki page", "quick Confluence correction", "update this section of <page>", "small correction to an existing page", "that fact is wrong on the runbook", "fix one row in a table on an existing page", "update this table row on the wiki", "correct one entry in this table", or any one-section edit to an existing page. Complements doc-coauthor (new pages/rewrites) and ticket-write-verify's confluence-large-restructuring reference (full reorgs) — this skill covers the lighter single-section case.
compatibility: Requires Confluence MCP (confluence_get_page, confluence_update_page).
---

# Confluence Section Edit

A small, targeted fix to one section of an existing Confluence page doesn't need `doc-coauthor`'s full template/frontmatter workflow. It does need the same care the Confluence API's own quirks require: touch only the target section, never round-trip the whole page through markdown, and verify the result before walking away.

## 1. Identify the target section

Fetch the page in raw storage format — not markdown, see the round-trip warning below: `confluence_get_page(page_id, convert_to_markdown: false)`. Locate the target heading (`h1`/`h2`/`h3`) by its text content.

**No real heading tag above the target content:** some pages use a visually-styled paragraph as a section label instead of an actual heading tag — e.g. `<p><u><strong>KV1</strong></u></p>` sitting above the content it labels, with no `h1`/`h2`/`h3` anywhere nearby. Don't treat this as a reason to fall back to a full-page fetch/edit — anchor on the nearest distinguishing element instead:

1. Search the storage-format HTML for the styled paragraph (or other non-heading element — a table cell, a bolded/underlined run) whose text matches the visual section label, the same way Step 1's heading search matches text content.
2. Treat that element as the anchor in place of a heading tag for Step 2's extract/reassemble boundary — its following siblings up to the next anchor (next styled-label paragraph, or a real heading if the page mixes both) define the section, exactly as a heading's following siblings would.
3. Everything else — scoping the edit to the extracted slice, reassembling, verifying — proceeds per Steps 2 and 6 unchanged. A missing heading tag is not license to widen the edit to the whole page.

**Oversized page (~50KB+ storage-format body exceeds the fetch's token limit):** let the fetch auto-save to a file instead of trying to inline the full body, then use `python`/`jq` to extract just the target section from the saved file. Apply the edit locally per Step 2, then submit via `content_file` rather than an inline content string.

**Determining a heading's real anchor ID** (for a deep link, not the edit itself): don't guess the `ac:anchor` fragment from the heading text — Confluence's generated anchor doesn't reliably match a predictable transform. Fetch the page's rendered view (not storage format) and look for the actual `id=` attribute Confluence assigned near that heading in the rendered HTML. Only fall back to linking the page without a fragment if the rendered view isn't available.

## 2. Scope the edit to that section, not the whole page

Don't fetch as markdown, edit the markdown, and push a full-page rewrite — Confluence-specific elements (`ac:structured-macro`, `ac:link`/`ri:page`, `<time>` date macros) don't round-trip through markdown reliably, and a full-page rewrite risks touching content outside the section you meant to fix.

1. Parse the fetched storage-format HTML (BeautifulSoup, `html.parser`).
2. Extract the target heading's tag plus its following siblings up to the next heading/`hr` boundary — the same by-index extraction `ticket-write-verify`'s [confluence-large-restructuring.md](../ticket-write-verify/references/confluence-large-restructuring.md) reference uses for full reorgs, just scoped to one section instead of the whole document.
3. Edit only within that extracted slice.
4. Re-insert it at the same position in the original tag list and submit the full reassembled body via `confluence_update_page` — the Confluence API has no partial-page PATCH, so "section-scoped" describes the *edit*, not the submit call, which still carries the whole page.

For a one-line factual correction inside a paragraph (no structural change), a direct text substitution within the fetched storage-format HTML is fine — the extract/reassemble steps above are for edits that touch list, heading, or macro structure, not a single word swap.

**Structural insert (new sibling paragraph, not a text swap):** adding a new paragraph between two existing elements — e.g. inserting a sibling `<p>` between two existing `<p>` tags under a section — is a distinct category from the one-line correction above, and it still belongs to the extract/reassemble path, not a full-page rewrite:

1. Extract the section slice per Step 2's steps 1–2 above (heading-anchored or styled-paragraph-anchored per Step 1).
2. Within that slice, insert the new element at the correct sibling position — after the specific existing sibling it follows, before the one it precedes — rather than appending it at the end of the section or rebuilding the slice from scratch.
3. Re-insert the modified slice and reassemble per Step 2's step 4. The insert is still section-scoped: only the slice's sibling list changes, nothing outside the section boundary.

**Full-page-update escape valve:** when the target page has no macros, nested lists, or tables, a full-page fetch/edit/`confluence_update_page` is an acceptable substitute for the section-scoped extract/reassemble procedure — the risk that procedure guards against (touching content outside the target section) is low on a genuinely simple page. Otherwise, use the extract/reassemble flow above or the one-line text-substitution case.

**`confluence_update_page` requires `title` even when it isn't changing** — a call with only `page_id`, `content_format`, and `content` fails with an `InputValidationError`. Always include the existing title explicitly.

## 3. Watch for double-JSON-encoded API responses

`confluence_get_page`/`confluence_update_page` return content that's double-JSON-encoded — a JSON string containing another JSON-encoded string. The tool's displayed output still shows the literal backslash-escapes from that outer JSON layer, so naively text-editing what's displayed is unsafe and risks corrupting the page.

Safe pattern:

1. Write the raw tool response to a file.
2. Run `json.loads()` twice on it to recover the real storage-format HTML.
3. Apply the edit per Step 2 above.
4. Diff-verify per Step 6 below before considering the edit done.

## 4. Avoid nested markdown lists inside numbered/bulleted items

A real nested markdown list inside a numbered or bulleted list item is a known breakage point — it can collapse the whole list into plain text on render. Use flowing paragraphs with dash-separated clauses instead of a nested sub-list when a list item needs more than one point.

## 5. Watch for known write corruption

Same identifier/URL/bracket corruption modes as any Confluence write apply here — see `ticket-write-verify`'s known corruption modes table before submitting if the edit touches underscore-heavy identifiers, bracket-style markers, or URLs with underscores.

**Images are a special case — read-side, not write-side.** `confluence_get_page` unconditionally flattens `<ac:image>`/`<ri:attachment>` macros into a bare `<img src="filename">` tag on every fetch, regardless of what's actually stored. A flattened `<img>` in the section you're editing is not proof the image is broken — see `ticket-write-verify`'s [confluence-macros.md](../ticket-write-verify/references/confluence-macros.md) § Image macros before touching it.

## 6. Verify — diff immediately after every edit

Never leave a section edit unverified:

1. Re-fetch the page (`confluence_get_page`, same `convert_to_markdown: false`) immediately after the update call.
2. Compare against what was intended — read the section back for a plain-text edit; run `ticket-write-verify`'s structural-element diff (macro/link/table/date-tag counts) if the edit touched more than a paragraph.
3. If the render is broken (a list collapsed, a macro dropped, a link stripped), fix and re-verify before considering the edit done — don't leave a page live in a broken state on a plan to check later.

**⚠️ Exception: if the edit touched an image macro, step 1's re-fetch is not valid evidence.** `confluence_get_page` always shows a flattened `<img>` tag for images whether or not the macro is actually correct — verify via the live rendered page (screenshot/browser) instead.

## What this skill doesn't do

- New pages, significant rewrites, or anything template-driven — that's `doc-coauthor`.
- Full-document reorganization (moving whole sections, folding an H2 into an H3) — that's `ticket-write-verify`'s [confluence-large-restructuring.md](../ticket-write-verify/references/confluence-large-restructuring.md).
