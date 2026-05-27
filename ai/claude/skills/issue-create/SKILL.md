---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: issue-create
description: Create a new task, issue, or story in the right system — GitHub Issues or Jira — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", or similar. Work org remotes → Jira Story (from local.json); personal GitHub repos → GitHub Issue; no repo → personal KB.
compatibility: Requires gh CLI, Atlassian MCP (for Jira).
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
- `github-current:<owner/repo>` → Path B (GitHub Issue in that repo)
- `memex` → Path C (GitHub Issue in personal KB)

**Voice transcription aliases**: If the repo name sounds like a voice transcription artifact, confirm with the user before routing. Do not run repo searches for guessed names.

---

## Path A — Jira (work)

Read `jira.*` from `~/.config/ai-skills/local.json` before creating issues.

### A1. Gather information

- **Summary**: clear, imperative title
- **Component**: only if your Jira workflow uses components and context is clear
- **Epic link**: only if the user names a specific epic; use `jira.epic_link_field`

If the request is vague, ask one clarifying question before proceeding.

### A2. Draft the description (user story format)

```
As a [role], I want [goal], so that [outcome].

Acceptance Criteria:
- [Criterion — what does done look like?]

Context:
- [Relevant links, docs, or references — omit if none]
```

**Role rules** (same as GitHub Issues):
- Use the hat the user is wearing — never "As I, I want"
- Product/security work → "an SRE" or "a team lead"; safe default: "an engineer and knowledge worker"
- Acceptance criteria are required — minimum one line

### A3. Create the Jira Story

Use the Atlassian MCP `jira_create_issue` tool with `jira.project_key` and `jira.default_issue_type` from local.json:

```json
{
  "fields": {
    "project": { "key": "<jira.project_key>" },
    "summary": "<title>",
    "issuetype": { "name": "Story" },
    "description": "<rendered user story description>"
  }
}
```

Capture the returned ticket key (e.g. `PROJ-12345`).

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

> **Account:** Export the personal token before `gh` calls to personal repos (`GITHUB_PERSONAL_USER` must be set):
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```

### B1. Gather information

- **Title**: imperative verb + clear description
- **Type or Domain**:
  - `ai-skills` repo → **type**: `new-skill`, `enhancement`, `bug`, or `review`
  - Other personal repos → **domain**: `work-primary`, `client-contract`, `homelab`, `learning`, `personal`, `mtb`, or `iot` (see `categories/tags.yaml`)
- **Priority**: `high`, `medium`, or `low` — infer; ask only if genuinely unclear
- **Due date**: only if explicitly stated

Draft the body using the user story template in §C2.

### B2. Seed missing labels

```bash
bash ~/.claude/skills/issue-create/scripts/seed-labels.sh <owner/repo>
```

### B3. Create the GitHub Issue

```bash
gh issue create \
  --repo <owner/repo> \
  --title "<title>" \
  --label "<type-or-domain>/<value>,priority/<priority>" \
  --body "<rendered user story body>"
```

### B4. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system github \
  --repo "<owner/repo>" \
  --id "<NUMBER>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>"
```

### B5. Confirm

Report: issue number, URL, and labels applied.

---

## Path C — GitHub Issue in personal KB

> **Account:** Same `GH_TOKEN` export as Path B.

Repo: `routing.personal_kb_github` from local.json (not hardcoded in this public skill).

### C1. Gather information

- **Title**: imperative verb + clear description
- **Domain**: `work-primary`, `client-contract`, `homelab`, `learning`, `personal`, `mtb`, or `iot`
- **Priority**: `high`, `medium`, or `low`

### C2. Draft the issue body (user story template)

```markdown
## Story
As a [role], I want [goal], so that [outcome].

## Acceptance Criteria
- [ ] [Criterion — what does done look like?]

## Context & Links
- Reference: [external URL, doc, or wiki link, if any]

> Add updates and blockers as comments, not edits to this body.
```

**Role rules:**
- Use the user's context — never "As I, I want"
- Map domain to a sensible role (e.g. `homelab` → "a homelab operator"; `personal` → "a family organizer")
- Safe default: "an engineer and knowledge worker"
- Acceptance criteria are required — minimum one line

### C3. Create the GitHub Issue

```bash
gh issue create \
  --repo <routing.personal_kb_github> \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>" \
  --body "<rendered user story body>"
```

### C4. Add to GitHub Project (optional)

If `github_projects.<domain>` is set in local.json:

```bash
gh project item-add <PROJECT_NUMBER> --owner <owner> --url <ISSUE_URL>
```

On missing `read:project` scope, continue and report:

```
⚠️ skipping project add — run `gh auth refresh -s read:project` to enable
```

### C5–C6. Logs and task index

Append to your vault's issues log and task index paths (see personal KB `AGENTS.md`). Use `append-task-index.sh` with `--repo` set to `routing.personal_kb_github`.

### C7. Confirm

Report: issue number, URL, project (or skip reason), and labels.
