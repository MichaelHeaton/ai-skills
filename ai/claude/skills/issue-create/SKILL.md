---
version: 1.3.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: claude
name: issue-create
description: Create a new task, issue, or story in the right system — GitHub Issues (Memex), Linear, or Jira — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", "this should be its own ticket", "split this into", "break this out", "separate ticket for X", "let's decompose", or similar. Work org remotes → Jira Story; personal work → GitHub Issue in Memex (default) or current repo; Linear only when routing file explicitly sets ticket_system=Linear.
compatibility: Requires gh CLI, Atlassian MCP (Jira path only).
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
- `memex` → Path C (GitHub Issue in Memex)
- `gitlab-current:<namespace/repo>` → Path B2 (GitLab Issue)
- `linear:<project>` → Path D (Linear issue — only when routing file sets `ticket_system=Linear`)

**Player / tester / playtest reports:** set `export ISSUE_ROUTE=github` before detect-context, or use Path B when the user explicitly asks for a GitHub issue.

**Personal GitHub orgs → Linear:** To force Linear routing for personal GitHub orgs (rather than GitHub Issues), set `PERSONAL_GITHUB_ORGS=org1,org2` in your shell or add `"personal_github_orgs": ["org1"]` to `~/.config/ai-skills/local.json`. Any repo whose GitHub org matches routes to `linear:<heuristic_project>`.

**Voice transcription aliases**: If the repo name sounds like a voice transcription artifact, confirm with the user before routing.

---

## Path A — Jira (work)

Read `jira.*` from `~/.config/ai-skills/local.json` before creating issues.

### A1. Gather information

- **Title**: imperative verb + clear description (user story format)
- **Priority**: `high`, `medium`, or `low`
- **Epic**: ask or infer from context

### A2. Fetch project components (required fields)

Before creating, fetch the project's components to pre-empt the "Component/s is required" error:

```
jira_get_project_components(project_key="<jira.project_key>")
```

Select the most relevant component based on ticket content and repo name. Include it in the creation call as `components: [{"name": "<component>"}]`. If no components exist for the project, skip this field.

### A3. Draft description and create

Draft the user story body using the template in §C2. **Critical**: pass the description body as a literal multi-line string — do **not** construct it with escaped `\n` characters. The Jira MCP requires real newlines; `\n` literals appear verbatim in the Jira UI.

Create via Atlassian MCP `jira_create_issue` with `jira.project_key`, the component from A2 (if applicable), and the multi-line description.

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

## Path C — GitHub Issue in Memex (default personal path)

> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

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

**Role rules:** Use the hat the user is wearing — never "As I, I want".

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
- Project add skipped: `"Created [#97 — ...](https://github.com/...) — not added to project (missing read:project scope; run \`gh auth refresh -s read:project\` to fix), priority/medium."`

---

## Path D — Linear issue (explicit opt-in only)

Only used when `~/.config/ai-skills/repo-routing.json` sets `ticket_system=Linear` for a repo.

Read `linear.team` from `~/.config/ai-skills/local.json` (e.g. `SpecterRealm`).

### D1. Gather information

- **Title**: imperative verb + clear description
- **Project**: from `linear:<project>` output
- **Domain**: map from project — see `references/routing.md`
- **Priority**: `high`, `medium`, or `low`

### D2. Draft the description — use the user story template from §C2

### D3. Create the Linear issue

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

### D4. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system linear \
  --id "<SR-NNN>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Linear project name>"
```

### D5. Confirm

Report: Linear identifier, URL, project, and priority.
