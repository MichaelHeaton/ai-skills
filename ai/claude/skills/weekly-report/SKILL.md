---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: weekly-report
description: Generate paste-ready weekly status files for two standing rhythms defined in local.json — typically a client-contract deck update and an employer team wiki (PPP). Routes by user intent and weekly_reports.* keys in ~/.config/ai-skills/local.json. Triggers on weekly report, client deck update, slides 8-10, dedicated defense update, team wiki weekly, PPP, Thursday meeting prep, weekly repost, or when the user names either rhythm from their private config labels.
compatibility: Vault paths in Memex; Jira MCP when work_team path needs it; requires ~/.config/ai-skills/local.json.
---




# Weekly Report

Two formats, configured in **`local.json`** under `weekly_reports` — keys are generic (`client_contract`, `work_team`); your private file holds real names, URLs, and paths.

## Step 0 — Load local config

Read `~/.config/ai-skills/local.json` ([references/local-config.md](../../../references/local-config.md)):

- `weekly_reports.client_contract` — deck / client-facing rhythm
- `weekly_reports.work_team` — employer team wiki rhythm
- `jira.*` when the work-team path needs tickets

If your vault has a rules doc at `weekly_reports.work_team.memex_agent_ref`, read it — vault rules win on conflict.

## Step 1 — Route

Use **private config labels** and user phrasing — do not hardcode employer names from a public template.

| User intent (examples) | Config key | Reference |
| ------------------------ | ------------ | ----------- |
| Client deck, slides 8-10, contract weekly, labels in `client_contract` | `client_contract` | [references/client-contract.md](references/client-contract.md) |
| Team wiki PPP, employer weekly, Thursday prep, labels in `work_team` | `work_team` | [references/work-team.md](references/work-team.md) |

If both in one message → **two output files** unless the user says otherwise.

If ambiguous, ask using their **`label`** fields from local.json (e.g. *"client contract deck or work team wiki?"*).

## Step 2 — Execute

Follow the reference file for the chosen key.

## Step 3 — Confirm

Link output file(s) under `Outputs/Weekly/`, note paste targets from the matching `weekly_reports.*` block, and call out gaps.
