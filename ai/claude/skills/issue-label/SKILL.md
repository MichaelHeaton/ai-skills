---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: issue-label
description: Audit a project's unlabeled tickets, propose a minimal label taxonomy, create missing labels, and apply them in bulk. Use when a backlog has grown unfilterable, or the user says "add labels to tickets", "triage the backlog", "organize tickets with labels", "label all the issues in X", or "this backlog needs labels". Works on GitHub Issues and Linear. For labeling a single ticket, use issue-update instead.
compatibility: Requires gh CLI (GitHub) or Linear MCP.
---

# Issue Label

Bulk-label a messy backlog without hand-tagging every ticket. The taxonomy is proposed, not imposed — nothing gets created or applied until the user confirms it.

## 1. Fetch the backlog

**GitHub**: `gh issue list --repo <owner/repo> --state open --json number,title,body,labels --limit 200` (paginate if the repo is large — see `issue-list`'s large-result-set fallback if the count exceeds a few hundred).

**Linear**: `list_issues` scoped to the target team/project.

## 2. Propose a taxonomy

Read titles and descriptions across the fetched set. Propose **3–8 labels** that would meaningfully partition the backlog — not one label per ticket, not a taxonomy so broad it doesn't filter anything. Favor dimensions already implicit in the tickets (type of work, subsystem, urgency) over inventing new categories.

Present the taxonomy with a one-line rationale per label and a rough count of how many existing tickets would get each one:

```
Proposed labels:
- type/bug (12 tickets) — defect reports
- type/enhancement (18 tickets) — improvement requests
- area/auth (6 tickets) — authentication subsystem
- priority/high (4 tickets) — flagged urgent in title/body
```

**Wait for the user to approve, adjust, or reject before creating anything.**

## 3. Create missing labels

Once approved, create any labels that don't already exist in the target system, with sensible colors (group related labels into a consistent color family — all `type/*` one hue, all `area/*` another).

**GitHub**: `gh label create "<name>" --repo <owner/repo> --color "<hex>" --description "<desc>"`

**Linear**: use the Linear MCP's label-creation call, scoped to the team.

## 4. Apply labels

Apply in parallel batches (multiple tickets at once) rather than one call per ticket serially — this is exactly the kind of bulk mutation `issue-update`'s smart-mode Auto-review gate expects; approve the first smart-mode card when it appears and group same-shape edits contiguously so the gate doesn't re-trigger mid-batch.

A ticket can get more than one label (e.g. `type/bug` + `area/auth` + `priority/high`) — don't force single-label assignment if the taxonomy has orthogonal dimensions.

## 5. Report

```
Created 3 labels: area/auth, area/billing, area/infra
Labeled 40 tickets (2 skipped — see below)
Skipped:
- #12 — ambiguous, couldn't confidently place in any proposed category
```

Don't force a label onto a ticket that doesn't clearly fit — an honest "skipped" list is more useful than false-positive coverage.
