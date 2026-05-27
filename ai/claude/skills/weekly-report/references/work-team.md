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

## Wiki structure

Use `display_name` as the heading (e.g. your name on the team page).

**Progress** — 2–5 sentences per bullet; ticket keys from `jira.project_key`; one item per bullet.

**Plans** — next-week actions with ticket refs.

**Problems** — only real blockers, or *(None this week.)*

Detail level should match teammates on the target wiki page.

## Metadata in output file

- Week ending date
- Wiki paste target URL (confirm before user pastes)

End with `## Sources consulted (internal)`.

Full rules: path in `weekly_reports.work_team.memex_agent_ref` (your private vault).
