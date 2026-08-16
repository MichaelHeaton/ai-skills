---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
---

# Atlassian MCP unreachable → fallback

Path A (Jira) uses Atlassian MCP tools exclusively — there is no CLI to fall back to the way GitHub paths fall back from `gh` to `mcp__github__*` (see [gh-mcp-fallback.md](gh-mcp-fallback.md)). When the Atlassian MCP itself is unreachable — a Keychain-blocked-in-sandbox failure, an expired token, the server not configured for this session — Path A has no built-in degradation path today, and a raw MCP error surfacing mid-flow is easy to misread as "no ticket was needed" rather than "the ticket couldn't be filed."

## Detecting the failure

Treat any of these as "Atlassian MCP unreachable," not as a reason to silently stop:

- `jira_get_project_components` (A2) or `jira_create_issue` (A3) raises a connection/auth/timeout error rather than a normal Jira API error (e.g. validation, permissions)
- The tool is not present in this session's tool list at all

## Fallback sequence

1. **Surface the failure explicitly** — state that Atlassian MCP is unreachable and the ticket was not created. Do not proceed as if the step succeeded or silently drop the request.
2. **Ask the user** (or, in an unattended/batch run, make the call and note the assumption): defer creation until Atlassian MCP is back, or fall back to a GitHub Issue in the current repo (Path B) / Memex (Path C) as a placeholder, with a note in the body that it should be re-filed in Jira once MCP is reachable.
3. **If falling back to GitHub**: use the same title and body content drafted for Path A, and prefix the body with a short note: `> Filed here as a placeholder — Atlassian MCP was unreachable when this was created. Re-file in Jira (<jira.project_key>) once available.` Append to the task index as normal for whichever system actually received the ticket (§A5 / B2–B5 / C6) — do not append a Jira task-index record for a ticket that was never created there.
4. **If deferring**: do not append to the task index (nothing was created), and say so plainly so the next session doesn't assume the ticket exists.

This mirrors the resilience `gh-mcp-fallback.md` gives the GitHub paths: surface the gap, offer a concrete next step, and never leave the caller assuming a ticket exists when it doesn't.
