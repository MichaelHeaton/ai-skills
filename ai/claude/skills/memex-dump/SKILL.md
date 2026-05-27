---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: memex-dump
description: Quickly capture raw, unstructured ideas, thoughts, and to-dos before they're lost — brain dump mode. For unresolved, untriaged captures only; if a decision is already made and needs a permanent home, use memex-decide instead. Creates a ticket instantly, always tagged for triage and grooming, so nothing falls through the cracks. Defaults to Memex (personal GitHub Issues). Workstation/dotfiles/browser ideas route to workstation-devops; skill/AI-workflow ideas route to ai-skills. Work Jira is suppressed unless a named PROJ epic was mentioned earlier in this session — rough thoughts don't belong in work systems. Use when the user says "brain dump", "capture this idea", "remember this", "quick note", "log this thought", "don't let me forget", "jot this down", "dump this", "dump this to memex", "quick capture", "brain dump to memex", "here are a few things to capture", "brain dump, multiple items", or any fast-capture variation — including lists of multiple ideas at once.
compatibility: Requires gh CLI. Shares scripts with issue-create.
---



# Memex Dump

Get the thought down first, triage later. Minimal friction, always tagged for cleanup.

Supports single ideas and batches — when the user provides a list, process each as its own ticket and confirm all at the end with a summary table.

## Routing

Routing uses two signals in order:

**1. Topic-based routing (check first)**

If the idea is clearly about one of these topics, route to the named repo regardless of which repo the user is currently in:

| Topic | Repo | System |
|---|---|---|
| Workstation setup, dotfiles, browser config (Brave/Chrome), dev environment, Homebrew, system tools, dashboard/homepage tools | `YOUR_USER/workstation-devops` | GitHub |
| Skill improvements, install scripts, AI workflow, Claude skill authoring | `YOUR_USER/ai-skills` | GitHub |

**2. Context-based routing (fallback)**

Run the context detector:

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

| Detected | Brain dump routes to |
|---|---|
| `jira-work` | Memex **unless** a named PROJ epic was mentioned in this session |
| `github-current:<personal>` | That repo **if** the idea is clearly scoped to it; otherwise Memex |
| `memex` | Memex |

When in doubt, route to Memex. Brain dumps are personal capture — don't push rough thoughts into work systems.

## Body format

Use a lite user story — role and goal, no acceptance criteria required:

```markdown
As a [role], I want [goal].

*Captured via brain-dump — needs triage.*
```

If the idea is too raw or abstract to fit a role/goal sentence, fall back to free-form:

```markdown
[Raw thought as captured]

*Captured via brain-dump — needs triage.*
```

Role rules are the same as `issue-create` §C2. Safe default for personal/workstation ideas: `"a developer and workstation operator"`.

## Steps

### 1. Extract title, domain, and route for each idea

For each idea (batch or single):

- **Title**: imperative verb + short description — infer from what the user said
- **Domain**: infer from context; ask only if completely ambiguous
  - GitHub/Memex domains: `work-primary`, `client-contract`, `homelab`, `learning`, `personal`, `mtb`, `iot`
  - Workstation-devops: use `workstation` in the task index — no GitHub Project assignment applies
- **Priority**: default to `medium`; adjust only if user signals urgency
- **Route**: apply topic-based routing first, then context-based fallback

If an idea is genuinely unclear, ask one short question — no more. Don't block the whole batch for one ambiguous item; flag it and move on.

### 2. Route and create

**Path M — Memex (default)**

> Export personal token before any `gh` call:
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```
> If `GITHUB_PERSONAL_USER` is not set, fall back to `gh auth token`.

Seed labels (idempotent):

```bash
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh ${GITHUB_PERSONAL_USER}/memex
```

Create the issue:

```bash
gh issue create \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>,type/brain-dump,triage/needs-grooming" \
  --body "<lite user story body>"
```

**Add to GitHub Project** — use domain → project routing from `references/routing.md`:

```bash
gh project item-add <PROJECT_NUMBER> --owner ${GITHUB_PERSONAL_USER} --url <ISSUE_URL>
```

**Append to `Raw/_GitHub-Issues-log.jsonl`:**

```json
{"v":1,"record":"issue","when":"YYYY-MM-DD","issue_number":NNN,"title":"...","url":"...","repo":"${GITHUB_PERSONAL_USER}/memex","vault_task":null,"labels":["domain/<domain>","priority/<priority>"],"notes":""}
```

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system github \
  --repo "${GITHUB_PERSONAL_USER}/memex" \
  --id "<NUMBER>" \
  --url "<ISSUE_URL>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Project Name>"
```

---

**Path R — Personal GitHub repo (scoped idea)**

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh <owner/repo>
gh issue create \
  --repo <owner/repo> \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>,type/brain-dump,triage/needs-grooming" \
  --body "<lite user story body>"
```

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system github \
  --repo "<owner/repo>" \
  --id "<NUMBER>" \
  --url "<ISSUE_URL>" \
  --title "<title>" \
  --domain "<domain>"
```

---

**Path J — Jira (active PROJ epic only)**

Create as Story with labels `brain-dump` and `needs-grooming` (Jira free-text labels). Link to the active epic via `customfield_11800`. See `issue-create` Path A for full Jira steps.

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system jira-work \
  --id "<KEY>" \
  --url "<url>" \
  --title "<title>" \
  --domain work-primary \
  --project PROJ
```

### 3. Confirm

**Single idea**: one-line confirm with issue number, URL, and where it landed.

**Batch**: summary table after all tickets are created.

| # | Title | Destination | Issue |
|---|---|---|---|
| 1 | … | workstation-devops | #N — link |
| 2 | … | Memex | #N — link |

### 4. Verify task-index (batch only)

After a batch run, confirm the appends landed:

```bash
# Count entries added — should equal number of tickets created
tail -n <COUNT> ~/Projects/personal/memex/Raw/_task-index.jsonl | jq -r '.id'
```

If the count is short, identify the missing IDs and append them manually before closing the session. Never leave a batch partially indexed.
