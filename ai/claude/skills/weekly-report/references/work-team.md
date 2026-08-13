---
version: 1.2.1
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Work-team weekly (wiki PPP)

Config: `weekly_reports.work_team` in `local.json`.

Output path: `output_file` in that block.

## Week ending

Confirm with user (often day before a standing team meeting — see `meeting_note` in config).

## Sources

- Jira MCP for `jira.project_key` / assignee = currentUser() when configured
- **For any ticket central to this week's narrative**, pull recent comments too (`jira_get_issue` with `comment_limit` set), not just status/description — a same-day comment can contradict a status claim built from search results or git-log alone
- Vault: recent meetings, dailies, prep notes per `memex_agent_ref`

## Format check

Before generating, fetch the current week's wiki page via Confluence MCP to verify active section headers and table layout. Do not rely solely on prior output files — format can change between weeks (e.g. numbered section headers may become plain `###` headers). If the page doesn't exist yet, use the most recent available page as reference.

**Also capture and match**, since these vary by page and a mismatch only surfaces as a manual correction after the draft is otherwise done:

- **Contributor heading style** — bare `@name` mention, bold markdown, or some other convention used for each person's section
- **Ticket-reference style** — inline key, full URL, sub-bullet placement

## Wiki structure

Use `display_name` as the heading (e.g. your name on the team page).

**Role clarification (verbally-provided items only):** Before drafting a Progress bullet for any work item described verbally (not sourced from a commit, Jira ticket, or vault note), ask whether the user was the **owner/doer** or an **observer/trainee**. Owner → draft a "I completed…" bullet. Observer → draft "attended/reviewed/supported…" framing. Do not assume ownership from vague phrasing like "worked on" or "helped with" — ask.

**Progress** — 1–2 sentences per bullet (TL;DR); ticket keys from `jira.project_key`; one item per bullet. The ticket carries the detail — lead with outcome and include the ref. Only expand beyond 2 sentences for items with no ticket or genuinely complex context with no other reference.

**Plans** — next-week actions with ticket refs.

**Problems** — only real blockers, or *(None this week.)*

**Updates from Leads table** — if the live wiki page has an effort-level summary table above the PPP section (e.g. `| Effort | Lead | Updates |`), include a paste target for any efforts the user owns as a separate section in the output file, before the Progress section.

- **Content**: short, punchy, one-line-per-item talking points — not the 2-5 sentence paragraph-style bullets used in Progress/Plans/Problems. Name the thing, not the detail; save ticket numbers, PR numbers, and "why it mattered" for the Progress bullets underneath.
- **Structure in the output file**: render it as a normal Markdown bullet list (one `*`/`-` item per line) under its own heading — do **not** embed it inside a `| |` Markdown table row/cell. Pipe-table cells can't hold real line breaks, so multi-point content forced into one either gets squashed onto a single `*`-separated line or `<br>`-joined — both paste into the live Confluence cell worse than a plain bullet list copies in as a bullet list. This was corrected 2026-08-13 after a first pass over-corrected a paste-breaking complaint into single-line prose, which was the wrong fix in the wrong direction — the working answer is short bullets, each on its own line, outside of a table cell in this file.

## Confluence-paste formatting

Confluence's paste handler doesn't render Markdown backtick syntax — the backtick characters show up literally in the pasted text. Worse, bare `word.tld`-shaped text (e.g. a filename like `AGENTS.md` or `variables.tf`) gets caught by Confluence's link-autodetect and turned into a broken hyperlink (e.g. `http://AGENTS.md`). Both problems only surface after paste, once the content is already live on the wiki page. Write filenames and variable names as plain text in this output, not wrapped in backticks — this is scoped to Confluence-paste output specifically; backticks are fine in output meant for GitHub or Jira, which render Markdown correctly.

## Metadata in output file

- Week ending date
- Wiki paste target URL (confirm before user pastes)

End with `## Sources consulted (internal)`.

Full rules: path in `weekly_reports.work_team.memex_agent_ref` (your private vault).
