---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Safe large-document restructuring pattern for Confluence

A repeatable procedure for reorganizing a large, heavily-macro'd Confluence page (moving sections, folding content into a new appendix) without silently losing or corrupting Confluence-specific elements — macros, page links, date tags.

## The anti-pattern: markdown round-trip

Fetching a page as markdown, editing it, and converting back to storage format is unsafe for structural reorganization. Confluence-specific elements (`ac:structured-macro`, `ac:link`/`ri:page`) don't round-trip reliably through markdown — they either flatten to plain text or get dropped outright. This is fine for a small text edit; it is not fine for moving whole sections around.

## The pattern: extract by index, reassemble

1. Fetch the page in raw storage format (`convert_to_markdown: false`).
2. Parse with BeautifulSoup (`html.parser`).
3. Get the flat list of top-level child tags: `tags = list(soup.children)`.
4. Identify section boundaries by locating heading (`h1`/`h2`/`h3`) and `hr` positions in that list.
5. Extract the relevant tag *objects* by index (Python list slicing on `tags`, not re-parsing text) and reassemble them in the new order into a fresh `BeautifulSoup("", "html.parser")` via `.append()`.
6. **Never re-serialize through markdown at any point in this process.**

Moving/demoting a heading (e.g. folding an `h2` section into another as a new `h3`) is the same operation — slice out the heading tag and its following content up to the next boundary, change the tag name, re-append in the new position. The section's inline macros travel with it automatically since they're still the same tag objects, not re-typed text.

## Required verification gate before pushing

Don't rely on manual proofreading alone for a reorg this size. Diff structural-element counts between the old and new HTML:

```python
soup.find_all('ac:structured-macro', attrs={'ac:name': 'jira'})  # Jira macros
soup.find_all('ac:link')                                          # internal page links
soup.find_all('table')                                            # tables
soup.find_all('time')                                             # date macros — compare datetime= values as a Counter, not just count
```

Confirm every count delta is fully explained by an intentional addition or removal (e.g. new macros added in new content), not accidental loss. This is the same check as the "structural drift" corruption mode in the main `SKILL.md` — reuse that re-fetch → diff → correct → re-verify loop rather than building a separate one for restructuring specifically.

A concrete case this caught: a reorg's own new content used plain-text dates instead of `<time>` tags — inconsistent with the rest of the document, caught by the count diff and fixed before push.
