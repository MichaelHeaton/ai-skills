---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
name: issue-create
description: Create a new task, issue, or story in the right system — Linear, GitHub Issues, or Jira — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", or similar. Work org remotes → Jira Story; personal work → Linear; GitHub Issues only when explicit or player/tester reports.
compatibility: Requires Linear MCP, gh CLI (GitHub path only), Atlassian MCP (Jira).
---

Create a new task in the right system based on where you're working. See `references/routing.md` for the full routing rules.

Once created, the description is the definition of done — treat it as frozen. All subsequent updates go in comments. If a description needs correcting after creation, see the description edit policy in `issue-update`.

## Steps

### 1. Detect routing target

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

The output tells you which path to follow:

- `jira-work` → Path A (Jira Story)
- `linear:<project>` → Path C (Linear issue)
- `github-current:<owner/repo>` → Path B (GitHub Issue in that repo)
- `gitlab-current:<namespace/repo>` → Path B2 (GitLab Issue)

**Player / tester / playtest reports:** set `export ISSUE_ROUTE=github` before detect-context, or use Path B when the user explicitly asks for a GitHub issue.

**Notion override:** When routing is ambiguous, fetch Repositories DB (`Ticket System`, `Linear Project`). See `references/routing.md` and `docs/guides/repo-routing-cache.md`.

**Voice transcription aliases**: If the repo name sounds like a voice transcription artifact, confirm with the user before routing.

---

## Path A — Jira (work)

Read `jira.*` from `~/.config/ai-skills/local.json` before creating issues.

### A1–A3

Same as before — gather info, draft user story, create via Atlassian MCP with `jira.project_key`.

### A4. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system jira \
  --id "<KEY>" \
  --url "<url>" \
  --title "<title>" \
  --domain work-primary \
  --project "<jira.project_key>"
```

### A5. Confirm

Report: ticket key, URL, and any epic it was linked to.

---

## Path B — GitHub Issue in current repo

> Use only when `detect-context` returns `github-current:*` or the user explicitly requests a GitHub issue / player report.
> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

### B1. Gather information

- **Title**: imperative verb + clear description
- **Type or Domain**:
  - `ai-skills` repo → **type**: `new-skill`, `enhancement`, `bug`, or `review`
  - Other repos → **domain** from `categories/tags.yaml`
- **Priority**: `high`, `medium`, or `low`

Draft the body using the user story template in §C2.

### B2–B5

Seed labels, `gh issue create`, append task index with `--system github`, confirm.

---

## Path C — Linear issue (default personal path)

Read `linear.team` from `~/.config/ai-skills/local.json` (e.g. `SpecterRealm`).

### C1. Gather information

- **Title**: imperative verb + clear description
- **Project**: from `linear:<project>` output
- **Domain**: map from project — see `references/routing.md`
- **Priority**: `high`, `medium`, or `low`

### C2. Draft the description (user story template)

```markdown
## Story
As a [role], I want [goal], so that [outcome].

## Acceptance Criteria
- [ ] [Criterion — what does done look like?]

## Context & Links
- Reference: [external URL, doc, or wiki link, if any]

> Add updates and blockers as comments, not edits to this body.
```

**Role rules:** Use the user's context — never "As I, I want". Safe default: "an engineer and knowledge worker".

### C3. Create the Linear issue

Use Linear MCP `save_issue`:

```json
{
  "title": "<title>",
  "team": "<linear.team from local.json>",
  "project": "<project from linear: output>",
  "description": "<rendered user story body>",
  "priority": 3
}
```

Priority: `high` → 2, `medium` → 3, `low` → 4.

### C4. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system linear \
  --id "<SR-NNN>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Linear project name>"
```

### C5. Confirm

Report: Linear identifier, URL, project, and priority.
