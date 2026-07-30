---
version: 2.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
name: memex-dump
description: Quickly capture raw ideas before they're lost. Creates a GitHub Issue in Memex by default, tagged for triage. Workstation ideas → domain/homelab (Workstation DevOps project); skill/AI-workflow → domain/learning (AI Skills project). Routes to Linear only when a repo's routing file sets ticket_system=Linear, and to Jira only when a named epic is in session. Use for brain dump, quick capture, "dump this to memex", etc.
compatibility: Requires gh CLI. Linear MCP only for opt-in Linear routing. GitHub path (modpack repo) for player/tester reports.
---

# Memex Dump

Get the thought down first, triage later.

## Routing

**1. Topic-based (check first)**

| Topic | Domain label | Project |
| --- | --- | --- |
| Workstation setup, dotfiles, browser, dev environment, Homebrew | `domain/homelab` | Workstation DevOps |
| Skill improvements, AI workflow, skill authoring (`ai-skills`; legacy `claude-skills`) | `domain/learning` | AI Skills |
| Homelab / infra | `domain/homelab` | Homelab |
| MTB / coaching | `domain/mtb` | MTB |
| Client / contract ops | `domain/uv-cyber` | UV Cyber |
| Modpack **dev** | `domain/personal` | Minecraft Modpacks |
| Modpack **player / tester** | GitHub in modpack repo (`ISSUE_ROUTE=github`) — unchanged | — |

All rows land in **Path M (GitHub Issue in Memex)** except the player/tester row, which already targets GitHub in the modpack repo directly.

**2. Context fallback**

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

| Detected | Route |
| --- | --- |
| `memex` (no remote) | Path M — GitHub Issue in Memex (default) |
| `github-current:*` | Path M unless player/tester or explicit request for that repo |
| `jira-work` | Path M (`domain/adobe`) unless a named epic is in session → Path J |
| `linear:<project>` | Path Li — only reached when the repo's routing file explicitly sets `ticket_system=Linear` |

Default: **Path M — GitHub Issue in Memex**, `domain/personal` unless the topic table above matches.

## Body format

Lite user story + `*Captured via brain-dump — needs triage.*`

## Steps

### 1. Extract title, domain, project, priority per idea

**URL splitting rule (SR-881):** If a brain dump item contains multiple URLs — whether listed under a header, inline in a paragraph, or grouped by topic — create **one ticket per URL**. The topic or category becomes context in the body, not a reason to merge. A single item may produce N tickets if it contains N URLs.

**Batch pre-flight (SR-880):** Before starting a batch of more than 3 items, verify the `append-task-index.sh` command is in the session allowlist. If it is not, either run it once manually to prompt approval first, or warn the user that an unattended batch may stall. Do not start a large unattended batch with unprimed permissions.

### 2. Route and create

**Path M — GitHub Issue in Memex (default)**

> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

```bash
gh issue create \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>,brain-dump,needs-grooming" \
  --body "<rendered lite user story body>"
```

Add to the matching GitHub Project (see table above) if one applies:

```bash
gh project item-add <PROJECT_NUMBER> --owner ${GITHUB_PERSONAL_USER} --url <ISSUE_URL>
```

If that fails with `missing required scopes [read:project]`, don't block — print `⚠️ skipping project add — run \`gh auth refresh -s read:project\` to enable` and continue.

Append to `~/Projects/personal/memex/Raw/_GitHub-Issues-log.jsonl` (same record shape as `issue-create` Path C5), then append the task index:

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system github \
  --repo "${GITHUB_PERSONAL_USER}/memex" \
  --id "<NUMBER>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Project Name>"
```

**Path G — GitHub (player/tester only)**

`export ISSUE_ROUTE=github` then `gh issue create` in the modpack repo. Append task index with `--system github`.

**Path Li — Linear (opt-in only)**

Only when `~/.config/ai-skills/repo-routing.json` sets `ticket_system=Linear` for the current repo, or the user explicitly asks for Linear. Linear MCP `save_issue` with `team` from `linear.team` in local.json, labels `brain-dump`, `needs-grooming`.

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system linear \
  --id "<SR-NNN>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Linear project>"
```

**Path J — Jira (active epic in session only)**

Read `jira.*` from `~/.config/ai-skills/local.json`. Fetch project components first to avoid "Component/s is required" errors:

```
jira_get_project_components(project_key="<jira.project_key>")
```

Draft a lite user story body (same format as Path M). Create via Atlassian MCP:

```json
{
  "project_key": "<jira.project_key>",
  "summary": "<title>",
  "issue_type": "Story",
  "description": "<body>",
  "priority": "<High|Medium|Low>",
  "components": [{"name": "<component>"}]
}
```

Append task index with `--system jira --domain work-primary`. Report: ticket key and URL.

### 3. Verify task index entries

After every creation (single or batch), verify the created ID(s) are present in the index. Do **not** use `tail -n <COUNT>` — prior appends in the same session will corrupt the count. Filter by the specific IDs created in this run:

```bash
jq -r 'select(.id == "<NNN>" or .id == "<NNN2>") | .id' \
  ~/Projects/personal/memex/Raw/_task-index.jsonl
```

All created IDs must appear. If any are missing, re-run the append step for those IDs before confirming.

### 4. Confirm

Single: one-line with issue number (markdown link) and project. Batch: summary table.

**Deprecated:** direct Linear `save_issue` calls bypassing routing — Linear free-tier limits mean unrouted captures should default to GitHub; Linear is reached only via the GitHub→Linear mirror or explicit opt-in (Path Li).
