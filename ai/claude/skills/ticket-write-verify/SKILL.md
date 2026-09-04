---
version: 1.4.0
principles_version: 1.0.0
last_updated: 2026-09-04
updated_by: claude
name: ticket-write-verify
description: Pre-check and auto-fix ticket-system writes (Jira, Confluence, GitHub) against known markdown/wiki-conversion corruption — underscore-escaping, bracket-tag stripping, dropped bold markers, stripped `+` characters, and structural drift on large edits. Wraps fragile identifiers before submit, then re-fetches and diffs after every create/comment/edit, auto-retrying with a correcting edit when corruption is found. Use for ad hoc Jira/Confluence writes outside issue-create/issue-update flows, correcting a batch of corrupted tickets, restructuring a Confluence page, building Confluence macros or internal links, or when asked "fix the mangled ticket text", "why did my underscores get escaped", "the brackets got stripped", "verify this ticket rendered correctly", or "why is this internal link broken". Also fires autonomously before any direct `confluence_update_page`/`jira_update_issue`/`jira_add_comment` call outside issue-create/issue-update's own flows.
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
| Image-macro flattening (read-side, not write) | Confluence | Any `<ac:image>`/`<ri:attachment>` macro, on **every** fetch via `confluence_get_page` — including `convert_to_markdown: false` | Read call always returns a bare `<img alt="filename.jpg" src="filename.jpg" width="..."/>`, regardless of what's actually stored server-side. This is the read tool lying, not evidence the write is broken — confirmed by the identical flattened form appearing in years-old page history, and by re-fetching immediately after writing a correct macro and seeing the same flattened tag while the live rendered page displayed correctly |

For a large-scale restructuring edit (not a small comment/description tweak), the post-write check in §2 below is structural rather than pattern-based: diff macro count, internal-link count, table count, and date-tag count between the old and new content, and flag any unexplained delta. This reuses the same re-fetch → diff → correct → re-verify loop, just counting structural elements instead of matching text patterns. Two references build on this same check instead of inventing a separate diff-verify pass: [references/confluence-macros.md](references/confluence-macros.md) (confirmed-working native macro/link XML, and a silent internal-link-stripping gotcha) and [references/confluence-large-restructuring.md](references/confluence-large-restructuring.md) (the extract-by-index-and-reassemble procedure for safely moving whole sections).

**Image macros break the standard re-fetch → diff loop** — `confluence_get_page` can never be used as verification evidence for image content, in either direction. See [references/confluence-macros.md](references/confluence-macros.md) § Image macros for the detection heuristic and the required live-page verification workaround.

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

---

## Optional: automated reminder hook

This skill is designed to fire autonomously before any direct `jira_add_comment`/`jira_update_issue`/`confluence_update_page` call made outside `issue-create`/`issue-update`'s own flows — but that's easy to miss from habit, matching this skill's trigger description closely without the `Skill` tool ever actually being invoked. A real session made several such direct calls with no corruption found on manual re-check, but the dedicated skill was never reached for. Two companion hooks close this gap without blocking anything, mirroring `git-ops`'s own `git-ops-track.py`/`git-ops-reminder.py` pattern:

- `hooks/ticket-write-verify-track.py` (`PostToolUse`, matcher `Skill`) — records that `ticket-write-verify`, `issue-create`, or `issue-update` fired this session (all three cover the same corruption check, so any one of them satisfies it)
- `hooks/ticket-write-verify-reminder.py` (`PreToolUse`, matcher on tool name) — prints a one-line nudge before a direct `jira_add_comment` / `jira_update_issue` / `confluence_update_page` call if none of those three skills has fired yet this session

Both are advisory only (always exit 0) and never block a call. They aren't wired into any tracked `settings.json` by default — this repo has no mechanism to write to a user's live `~/.claude/settings.json` on their behalf, so making them default-on isn't something a PR here can actually deliver. If direct ticket writes have slipped past this skill before, the fix is cheap: add them via the `update-config` skill now rather than waiting for a corruption incident.

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Skill", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/ticket-write-verify-track.py" }] }
    ],
    "PreToolUse": [
      { "matcher": "mcp__.*(jira_add_comment|jira_update_issue|confluence_update_page)", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/ticket-write-verify-reminder.py" }] }
    ]
  }
}
```

The `PreToolUse` matcher is a regex over the tool name, matched loosely (`mcp__.*(...)`) since the MCP server prefix (e.g. `mcp__atlassian__jira_add_comment`) varies by how the Atlassian MCP server is configured. The hook script itself re-checks the tool name against the same three method names before printing anything, so an unexpected matcher match on an unrelated tool is a no-op rather than a false nudge.
