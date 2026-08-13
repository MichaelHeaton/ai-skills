---
version: 1.2.1
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Work-team weekly — Problems / Plans / People

Config: `weekly_reports.work_team` in `local.json`.

Output path: `output_file` in that block (same file as the standard work-team path — adjust suffix if you need both formats in the same week).

## Week ending

Confirm with user (often the day before a standing team meeting — see `meeting_note` in config).

## Sources

- Jira MCP for `jira.project_key` / assignee = currentUser() — open blockers and next-sprint items
- **For any ticket central to this week's narrative**, pull recent comments too (`jira_get_issue` with `comment_limit` set), not just status/description — a same-day comment can contradict a status claim built from search results or git-log alone
- Recent git commits (last 7 days) across repos the user owns: `git log --since=1.week --oneline --author="$(git config user.name)"`
- **Same-day boundary check**: a blind `--since=1.week` window inconsistently includes/excludes commits landing on the same calendar day the prior report was generated. When any commit's date matches the prior report's generation date, don't rely on the date window alone — check the prior report's actual content/timestamp directly to determine what it already covered before including or excluding that commit here
- Vault: recent meetings, dailies, prep notes per `memex_agent_ref`

## Format check

Before generating, fetch the current week's Confluence wiki page (if `confluence_page_id` is set in config) to verify active section headers. Do not rely solely on prior output files — format can change between weeks.

## Output structure

Use `display_name` from config as the heading.

---

### Problems

Real blockers, risks, or dependencies the team needs to know about. If none, use *(None this week.)*

- **One bullet per problem** — name the blocker, who/what is blocking, and what's needed to unblock
- Include ticket key when one exists
- Skip resolved issues — only items still active at week-end

### Plans

Commitments for next week. These are what you're signing up to deliver, not a wish list.

- **One bullet per commitment** — specific enough that the team can hold you to it
- Include ticket key when one exists
- 3–6 bullets is the right range; more than 6 suggests scope creep

### People

Team moves, shoutouts, hiring updates, and org changes worth surfacing.

- **Shoutouts** — name someone who helped, delivered, or unblocked you this week
- **Hiring** — open reqs, interview pipeline updates, offer status (use initials if sharing publicly)
- **Org changes** — role changes, new starters, departures (only public info)
- If nothing notable: omit the section entirely rather than writing *(None this week.)*

---

## Confluence-paste formatting

Confluence's paste handler doesn't render Markdown backtick syntax — the backtick characters show up literally in the pasted text. Worse, bare `word.tld`-shaped text (e.g. a filename like `AGENTS.md` or `variables.tf`) gets caught by Confluence's link-autodetect and turned into a broken hyperlink (e.g. `http://AGENTS.md`). Both problems only surface after paste, once the content is already live on the wiki page. Write filenames and variable names as plain text in this output, not wrapped in backticks — this is scoped to Confluence-paste output specifically; backticks are fine in output meant for GitHub or Jira, which render Markdown correctly.

## Metadata in output file

- Week ending date
- Confluence paste target URL (from `weekly_reports.work_team.confluence_url` in config — confirm before user pastes)
- Format variant: `ppp: problems-plans-people`

End with `## Sources consulted (internal)`.

Full rules: path in `weekly_reports.work_team.memex_agent_ref` (your private vault). Private vault rules win on conflict.
