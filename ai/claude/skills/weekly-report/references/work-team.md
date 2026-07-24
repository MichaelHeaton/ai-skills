---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Work-team weekly (wiki PPP)

Config: `weekly_reports.work_team` in `local.json`.

Output path: `output_file` in that block.

## Week ending

Confirm with user (often day before a standing team meeting — see `meeting_note` in config).

## Sources

- Jira MCP for `jira.project_key` / assignee = currentUser() when configured
- Vault: recent meetings, dailies, prep notes per `memex_agent_ref`

## Format check

Before generating, fetch the current week's wiki page via Confluence MCP to verify active section headers and table layout. Do not rely solely on prior output files — format can change between weeks (e.g. numbered section headers may become plain `###` headers). If the page doesn't exist yet, use the most recent available page as reference.

## Wiki structure

Use `display_name` as the heading (e.g. your name on the team page).

**Role clarification (verbally-provided items only):** Before drafting a Progress bullet for any work item described verbally (not sourced from a commit, Jira ticket, or vault note), ask whether the user was the **owner/doer** or an **observer/trainee**. Owner → draft a "I completed…" bullet. Observer → draft "attended/reviewed/supported…" framing. Do not assume ownership from vague phrasing like "worked on" or "helped with" — ask.

**Progress** — 1–2 sentences per bullet (TL;DR); ticket keys from `jira.project_key`; one item per bullet. The ticket carries the detail — lead with outcome and include the ref. Only expand beyond 2 sentences for items with no ticket or genuinely complex context with no other reference.

**Plans** — next-week actions with ticket refs.

**Problems** — only real blockers, or *(None this week.)*

**Updates from Leads table** — if the live wiki page has an effort-level summary table above the PPP section (e.g. `| Effort | Lead | Updates |`), include a paste row for any efforts the user owns as a separate section in the output file, before the Progress section.

## Metadata in output file

- Week ending date
- Wiki paste target URL (confirm before user pastes)

End with `## Sources consulted (internal)`.

Full rules: path in `weekly_reports.work_team.memex_agent_ref` (your private vault).
