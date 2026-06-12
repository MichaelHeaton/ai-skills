---
version: 1.2.2
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: memex-dump
description: Quickly capture raw ideas before they're lost. Creates a Linear issue by default (SpecterRealm), tagged for triage. Workstation ideas → Linear Workstation DevOps; skill/AI-workflow → Linear AI Skills. Work Jira suppressed unless a named epic was mentioned. Use for brain dump, quick capture, "dump this to memex", etc.
compatibility: Requires Linear MCP. GitHub path only for player/tester reports.
---

# Memex Dump

Get the thought down first, triage later.

## Routing

**1. Topic-based (check first)**

| Topic | Linear project |
| --- | --- |
| Workstation setup, dotfiles, browser, dev environment, Homebrew | Workstation DevOps |
| Skill improvements, AI workflow, skill authoring (`ai-skills`; legacy `claude-skills`) | AI Skills |
| Homelab / infra | Homelab |
| MTB / coaching | MTB |
| Client / contract ops | UV Cyber |
| Modpack **dev** | Minecraft Modpacks |
| Modpack **player / tester** | GitHub in modpack repo (`ISSUE_ROUTE=github`) |

**2. Context fallback**

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

| Detected | Route |
| --- | --- |
| `jira-work` | Linear **Adobe** unless named epic in session → Jira |
| `linear:<project>` | That Linear project |
| `github-current:*` | GitHub only for player/tester or explicit request |

Default: Linear **Personal**.

## Body format

Lite user story + `*Captured via brain-dump — needs triage.*`

## Steps

### 1. Extract title, Linear project, domain, priority per idea

**URL splitting rule (SR-881):** If a brain dump item contains multiple URLs — whether listed under a header, inline in a paragraph, or grouped by topic — create **one ticket per URL**. The topic or category becomes context in the body, not a reason to merge. A single item may produce N tickets if it contains N URLs.

**Batch pre-flight (SR-880):** Before starting a batch of more than 3 items, verify the `append-task-index.sh` command is in the session allowlist. If it is not, either run it once manually to prompt approval first, or warn the user that an unattended batch may stall. Do not start a large unattended batch with unprimed permissions.

### 2. Route and create

**Path L — Linear (default)**

Linear MCP `save_issue` with `team` from `linear.team` in local.json, labels `brain-dump`, `needs-grooming`.

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system linear \
  --id "<SR-NNN>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Linear project>"
```

**Path G — GitHub (player/tester only)**

`export ISSUE_ROUTE=github` then `gh issue create` in modpack repo. Append task index with `--system github`.

**Path J — Jira (active epic in session only)**

Read `jira.*` from `~/.config/ai-skills/local.json`. Fetch project components first to avoid "Component/s is required" errors:

```
jira_get_project_components(project_key="<jira.project_key>")
```

Draft a lite user story body (same format as Path L). Create via Atlassian MCP:

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
jq -r 'select(.id == "SR-NNN" or .id == "SR-NNN2") | .id' \
  ~/Projects/personal/memex/Raw/_task-index.jsonl
```

All created IDs must appear. If any are missing, re-run the append step for those IDs before confirming.

### 4. Confirm

Single: one-line with SR-id and project. Batch: summary table.

**Deprecated:** `gh project item-add` for Memex GitHub Projects.
