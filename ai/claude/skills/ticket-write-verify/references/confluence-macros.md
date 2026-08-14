---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Confluence native macros and page-link gotchas

Confirmed-working storage-format XML for the Confluence constructs that don't have an obvious plain-markdown equivalent, plus one silent-failure mode worth knowing before it burns a document a stakeholder is actively reviewing.

## Internal page links — the costly gotcha

Some Confluence Data Center instances silently strip the `ri:content-id` attribute on internal page links at save time, leaving an empty `<ri:page>` that renders as "Broken link" in the UI — no error at write time, no warning, nothing until a human looks at the rendered page.

**Don't use** `ri:content-id` for internal links on an instance where this has been observed. **Use** title + space key instead:

```xml
<ac:link><ri:page ri:content-title="Target Page Title" ri:space-key="SPACEKEY" /><ac:plain-text-link-body><![CDATA[Link text]]></ac:plain-text-link-body></ac:link>
```

**Detection**: since this failure is silent at write time, fetch the page in raw storage format (`convert_to_markdown: false`) after any internal-link edit and grep for empty `<ri:page>` elements — don't trust that the write succeeded just because the API call returned success.

## Native Jira issue macro

Renders a live-status smart card instead of a static link, so a table referencing tickets doesn't need a manually-maintained status column that goes stale:

```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1">
  <ac:parameter ac:name="server">Adobe JIRA Data Center</ac:parameter>
  <ac:parameter ac:name="columns">issuekey,summary,issuetype,created,updated,duedate,assignee,reporter,priority,status,resolution</ac:parameter>
  <ac:parameter ac:name="columnIds">key,summary,type,created,updated,due,assignee,reporter,priority,status,resolution</ac:parameter>
  <ac:parameter ac:name="serverId">5affdfe8-ed2e-3a17-8442-0790430373f0</ac:parameter>
  <ac:parameter ac:name="key">PROJ-XXXXX</ac:parameter>
</ac:structured-macro>
```

`server`/`serverId` are instance-specific — confirm the actual values for the target Confluence instance rather than reusing the example verbatim.

## Native date macro

```xml
<time datetime="YYYY-MM-DD" />
```

## Title-field HTML-entity gotcha

The Confluence MCP's `update_page` `title` parameter does not reliably decode HTML entities — passing `&mdash;` can produce a literally mangled title (e.g. rendered as `);` in place of an em dash) rather than the intended character. Pass the literal Unicode character (an actual `—`) instead of an HTML entity.

## Relationship to the rest of this skill

These are construction templates, not corruption patterns — use them when *building* Confluence content. Once written, run this skill's normal post-write verify-and-fix loop (§2 in `SKILL.md`) to confirm the save didn't silently strip or mangle anything, including the `ri:page` check above.
