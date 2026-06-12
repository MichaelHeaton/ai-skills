---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: human
---



# Confluence push instructions

All commands run from the work docs repo with credentials loaded (page IDs in that repo's `.env`):

```bash
export $(cat .env | xargs)
```

## 7a. Update the Wiki Findings page

Pull: `python3 scripts/pull_page.py --page-id <FINDINGS_PAGE_ID> --output-dir /tmp/confluence-pull`

Edit `/tmp/confluence-pull/wiki-findings-and-proposed-changes.md`:

**1. Add a row to the session index table.**

Find the most recent "Index — [Date] Session" section. If today's date is within that range, add item(s) to its table. If it's a new day, insert a new `## Index — [Month DD] Session` section above the previous one with a fresh table. Use the next available item number.

Row format: `| {N} | {Short description of what changes} | {File(s) affected and what's added} | {⚠️ Blocked on Q{N} — reason / ✅ Ready — no blockers} |`

**2. Add detailed edit sections.**

Insert new section content above the most recent existing session's detailed edits block. Format: `### {N}. {Page title}`, URL, status note, source thread citation, proposed content block.

**3. Add new Q items to "Blocked / Needs Team Input".**

Prepend a row: `| **Q{N} — {title}:** {question + research context} | {Owner} | Item {#} | [Thread]({slack_permalink}) |`

Header: `| Question | Owner | Unblocks | Thread |`

**4. Update the Companion Docs table** with new thread count from the generated report.

Push: `python3 scripts/push_page.py /tmp/confluence-pull/wiki-findings-and-proposed-changes.md`

## 7c. Staged wiki page copies

When a gap action requires updating a live wiki page, stage it as a child page. **One staged copy per target wiki page — not one per item.**

Check for existing staged copy using Atlassian MCP: list children of the Wiki Findings page (ID `<FINDINGS_PAGE_ID>`). If a `[STAGED] {title}` page already exists, pull and append to the Addresses note. If not, create a new child page.

**Staging note format** (open every staged page with this block):

```
> ⚠️ **STAGING NOTE — remove this block before pushing to the live wiki**
> **Addresses:** Item {N} — {short description}[; Item {M} — {short description}; ...]
> **Status:** {✅ Ready — no blockers / ⚠️ Blocked on Q{N} — reason}
```

**Page title format:** `[STAGED] {original wiki page title}`

## 7b. Push the support bot Performance Report

Pull: `python3 scripts/pull_page.py --page-id <PERF_REPORT_PAGE_ID> --output-dir /tmp/confluence-pull`

Replace everything after the closing `---` of the frontmatter in the pulled file with the full content of `SHERLOCK-REPORT.md`. Keep the frontmatter intact.

Push: `python3 scripts/push_page.py /tmp/confluence-pull/sherlock-performance-report.md`

Confirm both Confluence pages were pushed (include version numbers from the push output).
