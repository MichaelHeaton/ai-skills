---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: research-finding-to-comment
description: Turn an ad hoc research lookup done for a ticket — Confluence search, doc/wiki dig, config check, log dig, web search — into a structured "Documented findings" comment, posted through the verified write path (issue-update, chaining into ticket-write-verify) instead of a raw MCP call. Use right after finishing a lookup done to answer a question on a specific ticket, before continuing further work on it. Triggers on "post what I found to the ticket", "document this finding on PROJ-12345", "write this up as a comment", "add my research to the ticket", "log what I found on #94", "summarize this search as a ticket comment", or noticing you're about to call a raw Confluence/Jira/GitHub write tool to record a lookup's result. Works for any research source paired with any ticket system issue-update supports (GitHub, GitLab, Jira). Distinct from issue-focus's load/brief/track lifecycle — fires regardless of how the ticket was opened; issue-focus has no findings-posting step of its own.
compatibility: Requires whatever the research step itself needs (Confluence/Atlassian MCP, filesystem/log access, web search) plus issue-update's own requirements for the target ticket system.
---

# Research Finding to Comment

Close the loop on "I looked something up for this ticket" by turning the result into a durable, structured comment — routed through the same verified write path every other ticket comment uses, not a one-off MCP call that skips the corruption check and the task-index sync.

This skill covers the second half of a two-step pattern: some other action (a manual search, `issue-focus`, a raw doc lookup) already did the research. This skill starts once that research is done and a finding exists to record.

## When this applies

Fire this whenever a research lookup was performed **in service of a specific ticket** and the natural next step is to write up what was found, before moving on to further work on that ticket:

- Confluence/wiki search to answer a question the ticket raised
- Reading through internal docs or a runbook
- Checking a config file or environment value
- Digging through logs to confirm or rule out a cause
- A web search for an external reference, changelog, or known-issue report

The trigger is **finishing the lookup**, not how the ticket got opened. A ticket opened through `issue-focus`, fetched with `issue-get`, pulled from `issue-list`, or just referenced by a bare ID (`PROJ-12345`, `#94`) all lead to the same "now document what I found" moment. `issue-focus`'s own lifecycle (brief, AC checklist, session tracking) has no dedicated step for this — its "add a comment" guidance just says to route through `issue-update`, the same instruction this skill follows. Don't wait for `issue-focus` to be active to use this.

## Step 1 — Confirm there's a ticket to write to

Identify the ticket this research was done for. If it's not already established in the conversation, ask which ticket the finding belongs to rather than guessing — a documented-findings comment posted to the wrong ticket is worse than not posting one.

## Step 2 — Structure the finding

Don't paste raw search output or a stream-of-consciousness recap. Build a comment with these parts:

```
**Documented findings** — YYYY-MM-DD

**Searched:** [what was looked up, and where — e.g. "Confluence space ENG for
prior incidents matching this error", "config/production.yaml for the timeout
value", "application logs 09-10 through 09-14 for the failing request ID"]

**Found:**
- [Finding one, with a source reference — a Confluence page title/link, a
  file path and line, a log timestamp, a URL]
- [Finding two, same treatment]

**Conclusion / recommendation:** [what this means for the ticket — confirms
a hypothesis, rules one out, points at a next action — or "inconclusive,
next step is X" if the search didn't resolve the question]
```

Keep each finding traceable to a concrete source — a page title, file path, log line, or URL — so a reader can go verify it later without redoing the search. If the search came up empty or inconclusive, say so explicitly rather than omitting the comment; "checked X, found nothing relevant" is still a useful record.

## Step 3 — Post through the verified write path, not a raw MCP call

Route the actual write through **`issue-update`** _(global: ai-skills)_ — do not call `jira_add_comment`, `confluence_update_page`, `gh issue comment`, or `glab issue note` directly.

`issue-update` already:

- Identifies the right system and repo/project from the ticket ID
- Posts the comment via the correct CLI/MCP call for that system
- Chains into its own post-write corruption check (`\_`-escaping, dropped bold markers, stripped brackets) — the fuller version of that check lives in **`ticket-write-verify`** _(global: ai-skills)_, which `issue-update` already references for ad hoc writes
- Leaves the task index alone for a comment-only update (no status change), consistent with how it handles any other comment

A structured findings comment is exactly the kind of ad hoc, outside-issue-create/issue-update-flow write `ticket-write-verify` calls out — but since this skill posts _through_ `issue-update`, `issue-update`'s own chained check already covers it. Reach for `ticket-write-verify` directly only if you're posting the finding somewhere `issue-update` doesn't reach (e.g. a Confluence page itself, rather than a ticket comment).

## Step 4 — Confirm to the user

Report what was posted and where, the same way `issue-update` does:

- "Added Documented findings comment to [PROJ-12345](url) — summarized the Confluence search on retry-timeout precedent."

## Scope note

This skill is intentionally not limited to Confluence+Jira. `issue-update` already writes to GitHub Issues, GitLab Issues, and Jira; a findings comment from any research source (doc search, config check, log dig, web search) can go to any of those. Narrowing this skill to one source/system pairing would be narrower than the write path it depends on, for no real benefit — the structuring step in Step 2 doesn't care where the finding came from or which ticket system it lands in.
