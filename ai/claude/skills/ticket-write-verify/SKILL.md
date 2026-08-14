---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: ticket-write-verify
description: Pre-check and auto-fix ticket-system writes (Jira, Confluence, GitHub) against known markdown/wiki-conversion corruption — underscore-escaping, bracket-tag stripping, dropped bold markers, stripped `+` characters, and structural drift on large edits. Wraps fragile identifiers before submit, then re-fetches and diffs after every create/comment/edit to catch what the pre-check missed, auto-retrying with a correcting edit when corruption is found. Use for ad hoc Jira/Confluence writes outside issue-create/issue-update's own flows, for correcting a batch of already-corrupted tickets, for restructuring a Confluence page or any large-scale storage-format edit, or whenever asked to "fix the mangled ticket text", "why did my underscores get escaped", "the brackets got stripped", or "verify this ticket rendered correctly". Also fires autonomously — always use this skill before any direct `confluence_update_page`/`jira_update_issue`/`jira_add_comment` call made outside issue-create/issue-update's own flows, not just after a user reports corruption.
compatibility: Requires the ticket system's API/MCP (Atlassian MCP for Jira/Confluence, gh CLI for GitHub).
---

# Ticket Write Verify

Ticket-system write APIs silently corrupt certain text patterns during markdown-to-storage-format conversion. This skill catches it before submit where possible, and always catches it after, by re-fetching and diffing.

**Relationship to issue-create / issue-update**: those skills already run a lighter version of the post-write check inline (issue-create §A3, issue-update §3) for their own create/update flows. Use this skill directly when writing to a ticket **outside** those flows — a one-off Jira comment, a Confluence page edit, correcting several already-mangled tickets in a batch — or when the fuller pre-check below is worth running before drafting.

---

## Known corruption modes

| Mode | System | Trigger | Symptom |
| --- | --- | --- | --- |
| Underscore-escaping | Jira | Identifiers with `_` (snake_case names) | `\_` appears even inside backticks/`{{...}}` — that wrapping is not a workaround |
| Bracket-tag stripping | Jira | `[STEP]`-style bracket markers in prose | Brackets vanish, bare text remains — API reads it as malformed link syntax |
| Underscore-escaping | Confluence | Same as Jira | Same symptom; storage-format conversion, not the editor |
| Query-string URL mangling | Jira/Confluence | URLs with `_` in query params | Underscore inside the URL gets escaped, breaking the link |
| Bold/plus stripping | Jira | `**bold**`, `+` characters | Bold markers dropped or rendered literally; `+` silently removed |
| Structural drift | Confluence (large edits) | Large-scale storage-format restructuring — internal page-link rewrites, section reordering | Macro (`ac:structured-macro`), link (`ac:link`), table, or date-tag counts change without a matching intentional add/remove — probable accidental loss, not a corruption pattern with a fixed signature |

For a large-scale restructuring edit (not a small comment/description tweak), the post-write check in §2 below is structural rather than pattern-based: diff macro count, internal-link count, table count, and date-tag count between the old and new content, and flag any unexplained delta. This reuses the same re-fetch → diff → correct → re-verify loop, just counting structural elements instead of matching text patterns. See companion tickets #358 and #359 (Confluence macro/link gotchas; safe large-document restructuring pattern) — this check is the shared verification mechanism those should build on rather than each inventing a separate diff-verify pass.

---

## 1. Pre-check before submit

Before posting any Jira or Confluence content, scan the drafted text for the fragile patterns above:

- **Underscore-heavy identifiers**: wrap in real inline-code formatting via the tool's actual code-span mechanism — plain backtick characters typed as text are **not** sufficient; use whatever field/param the MCP call exposes for inline code, not literal `` ` `` characters in the body string.
- **Bracket-style markers** (`[STEP]`, `[NOTE]`): rephrase as a bold label or a leading dash instead of literal brackets, since brackets read as link syntax regardless of formatting.
- **URLs with underscores**: pass as an actual link/href object where the API supports one, not inline as escaped text.

If the target field doesn't support real inline-code or link objects (a plain-text field), skip the pre-check for that field — the post-write check below is the backstop.

---

## 2. Post-write verify-and-fix loop

After every create, comment, or edit call:

1. **Re-fetch** the content immediately — `jira_get_issue` / `jira_get_comment` (Jira), the Confluence MCP's page-read call, or `gh issue view <n> --json body,comments` (GitHub).
2. **Diff** the fetched text against what was sent. Look specifically for: `\_` where a plain `_` was sent, missing brackets around a marker that had them, dropped `**bold**`, missing `+`.
3. **If corrupted**, correct via a follow-up edit call (`jira_update_issue` / `jira_edit_comment`, the Confluence MCP's update call, or `gh issue edit` / `gh issue comment --edit-last`) — rephrasing the fragile pattern per §1 rather than resubmitting the same text and hitting the same corruption again.
4. **Re-verify once more** after the fix. If still corrupted, stop and report the specific field and pattern rather than looping indefinitely — some corruption modes may not have a working escape sequence, and that's worth surfacing rather than silently retrying.

## 3. Batch correction

When fixing several already-corrupted tickets in one pass (rather than at write-time), run step 2's diff against each ticket's *current* stored content first to confirm it's actually corrupted before editing — don't blind-fix a list based on an assumption that all of them hit the same mode.

## 4. Report

Summarize what was checked and what needed fixing:

```
✓ 3 comments verified clean
✗ 2 corrected — PROJ-123 (bracket-tag stripping), PROJ-124 (underscore-escaping)
```
