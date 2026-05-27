---

name: issue-create
description: Create a new task, issue, or story in the right system — GitHub Issues or Jira CESSS — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", or similar. Context-aware: Adobe repos → Jira Story; personal GitHub repos → GitHub Issue in that repo; no repo → Memex.
compatibility: Requires gh CLI, Atlassian MCP (for Jira).
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


Create a new task in the right system based on where you're working. See `references/routing.md` for the full routing rules.

Once created, the description is the definition of done — treat it as frozen. All subsequent updates go in comments. If a description needs correcting after creation, see the description edit policy in `issue-update`.

## Steps

### 1. Detect routing target

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
```

The output tells you which path to follow:
- `jira-cesss` → Path A (Jira Story)
- `github-current:<owner/repo>` → Path B (GitHub Issue in that repo)
- `memex` → Path C (GitHub Issue in Memex)

**Voice transcription aliases**: If the repo name sounds like a voice transcription artifact (e.g. "Mimics" → Memex, "Memex" is correct), confirm with the user before routing. Do not run repo searches for guessed names.

---

## Path A — Jira CESSS Story

### A1. Gather information

- **Summary**: clear, imperative title
- **Component**: infer from context (`Vault`, `AWS Info`, or leave blank if unclear)
- **Epic link**: only if the user names a specific epic; use `customfield_11800`

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
- Use the hat Michael is wearing — never "As I, I want"
- `Vault` work → "a Vault team lead" or "an SRE"; `AWS` work → "an AWS operator"; general CES → "a CES security engineer"
- Safe default: "an SRE and knowledge worker"
- Acceptance criteria are required — minimum one line

### A3. Create the Jira Story

Use the Atlassian MCP `jira_create_issue` tool:

```json
{
  "fields": {
    "project": { "key": "CESSS" },
    "summary": "<title>",
    "issuetype": { "name": "Story" },
    "description": "<rendered user story description>"
  }
}
```

Capture the returned ticket key (e.g. `CESSS-12544`).

### A4. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system jira-adobe \
  --id "<KEY>" \
  --url "<url>" \
  --title "<title>" \
  --domain adobe \
  --project CESSS
```

### A5. Confirm

Report: ticket key, URL, and any epic it was linked to.

---

## Path B — GitHub Issue in current repo

> **Account:** The active `gh` account may be a work account. Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment):
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```

### B1. Gather information

- **Title**: imperative verb + clear description
- **Type or Domain**:
  - `claude-skills` repo → **type**: `new-skill`, `enhancement`, `bug`, or `review`
  - All other personal repos → **domain**: `adobe`, `uv-cyber`, `homelab`, `learning`, `personal`, `mtb`, or `iot`
- **Priority**: `high`, `medium`, or `low` — infer; ask only if genuinely unclear
- **Due date**: only if explicitly stated

Draft the body using the user story template in §C2.

If the request is vague, ask one clarifying question.

### B2. Seed missing labels

Before creating the issue, run the label seeder to ensure the required labels exist. Idempotent — no-op if labels are already present.

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

Capture the returned URL and extract the issue number.

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

## Path C — GitHub Issue in Memex

> **Account:** The active `gh` account may be a work account. Export the personal token before any `gh` call (`GITHUB_PERSONAL_USER` must be set in your environment):
> ```bash
> export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
> ```

### C1. Gather information

- **Title**: imperative verb + clear description
- **Domain**: `adobe`, `uv-cyber`, `homelab`, `learning`, `personal`, `mtb`, or `iot`
- **Priority**: `high`, `medium`, or `low`
- **Due date**: only if explicitly stated

If the request is vague, ask one clarifying question.

### C2. Draft the issue body (user story template)

```markdown
## Story
As a [role], I want [goal], so that [outcome].

## Acceptance Criteria
- [ ] [Criterion — what does done look like?]

## Context & Links
- Vault: [link to relevant vault note, if any]
- Reference: [external URL, doc, or wiki link, if any]

> Add updates and blockers as comments, not edits to this body.
```

**Role rules:**
- Use the hat Michael is wearing — never "As I, I want"
- `adobe` → "an SRE" or "a Vault team lead"; `uv-cyber` → "a UV Cyber director"; `homelab` → "a homelab operator"; `learning` → "an engineer upskilling on AI tooling"; `mtb` → "an MTB coach"; `personal` → "a parent" or "a family organizer"
- Safe default: "an SRE and knowledge worker"
- Acceptance criteria are required — minimum one line
- Omit Context & Links lines with nothing to fill in

### C3. Create the GitHub Issue

```bash
gh issue create \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>" \
  --body "<rendered user story body>"
```

Capture the returned URL and extract the issue number.

### C4. Add to the correct GitHub Project

Use the domain → project routing from `references/routing.md`:

```bash
gh project item-add <PROJECT_NUMBER> --owner ${GITHUB_PERSONAL_USER} --url <ISSUE_URL>
```

If the command fails with `missing required scopes [read:project]`, **do not exit or abort** — continue to C5. Set a flag so C7 can report the skip. Print exactly:

```
⚠️ skipping project add — run `gh auth refresh -s read:project` to enable
```

### C5. Append to `Raw/_GitHub-Issues-log.jsonl`

```json
{"v":1,"record":"issue","when":"YYYY-MM-DD","issue_number":NNN,"title":"...","url":"...","repo":"${GITHUB_PERSONAL_USER}/memex","vault_task":null,"labels":["domain/<domain>","priority/<priority>"],"notes":""}
```

Append to `~/Projects/personal/memex/Raw/_GitHub-Issues-log.jsonl`.

### C6. Append to task index

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

### C7. Confirm

Report: issue number and URL as a markdown link, project it was added to (or skipped with reason), and labels applied.

- Normal: `"Created [#97 — Review HomeLab DNS config](https://github.com/...) → HomeLab project, priority/medium."`
- Project add skipped: `"Created [#97 — Review HomeLab DNS config](https://github.com/...) — not added to project (missing read:project scope; run \`gh auth refresh -s read:project\` to fix), priority/medium."`

