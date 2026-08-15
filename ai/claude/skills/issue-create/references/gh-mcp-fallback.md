---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# `gh` CLI → MCP fallback

`issue-create` (and `issue-triage`, which delegates creation to it) defaults to `gh` for the GitHub paths. Some environments — cloud/web sessions in particular — have no `gh`/`hub` binary at all, only `mcp__github__*` MCP tools. Check once at Step 0 and use this table for every `gh` call below instead of improvising a substitution mid-flow.

| `gh` command | Used in | `mcp__github__*` equivalent |
| --- | --- | --- |
| `gh issue list --search "<kw>" --state open --json ...` | De-dupe check | `search_issues(owner: "<owner>", repo: "<repo>", query: "<keywords>")` — takes natural-language matching, not qualifier syntax; already scoped to `is:issue` and the given repo via its own `owner`/`repo` params (don't embed `repo:`/`is:` in the query string). Treat results as candidates to eyeball, same as the existing close-match check. `list_issues(owner, repo, state: "OPEN")` filtered client-side is the fallback if `search_issues` misses an exact-phrase match. |
| `gh repo view <owner/repo> --json isPrivate -q '.isPrivate'` | B0 (public repo check) | No reliable single-repo visibility lookup exists via this MCP server — `search_repositories` doesn't support a `repo:` qualifier (that's issue/PR-search-only syntax) and returns no reliable exact match on a repo search. When `gh` is unavailable, skip the lookup and print the public-repo warning unconditionally instead of trying to detect visibility — an unnecessary warning on a private repo is harmless, a missing one on a public repo isn't. |
| `gh issue create --repo ... --title ... --label ... --body ...` | B2, C3 | `issue_write(method: "create", owner, repo, title, body, labels: [...])` |
| `gh issue view <N> --repo ... --json comments,updatedAt` | B5, C7 (freshness re-check) | `issue_read(method: "get", owner, repo, issue_number: N)` for `updatedAt`, plus `issue_read(method: "get_comments", ...)` for new comments |
| `gh project item-add <PROJECT_NUMBER> --owner ... --url ...` | C4 | **No MCP equivalent** — GitHub Projects (v2) isn't exposed by this MCP server. Skip the step and report it in the confirmation, same as the existing missing-`read:project`-scope path. |
| `gh issue close <N> --repo ...` | `issue-triage` step 5 | `issue_write(method: "update", owner, repo, issue_number: N, state: "closed", state_reason: "not_planned" \| "completed")` |

Jira (Path A) already uses MCP tools exclusively — nothing to substitute there.
