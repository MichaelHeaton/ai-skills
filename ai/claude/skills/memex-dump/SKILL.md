---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
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

See `issue-create` Path A.

### 3. Confirm

Single: one-line with SR-id and project. Batch: summary table.

**Deprecated:** `gh project item-add` for Memex GitHub Projects.
