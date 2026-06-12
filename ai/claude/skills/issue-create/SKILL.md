---
version: 1.6.0
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: issue-create
description: Create a new task, issue, or story in the right system — GitHub Issues (Memex), Linear, or Jira — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", "this should be its own ticket", "split this into", "break this out", "separate ticket for X", "let's decompose", "log this as a backlog item", "track this for later", "create a ticket for this finding", or similar. Also fires autonomously — always use this skill when Claude itself decides to create any issue (during triage, research, session-close, or any workflow), when creating multiple issues in a batch, or whenever about to call gh issue create or glab issue create directly. Work org remotes → Jira Story; personal work → GitHub Issue in Memex (default) or current repo; Linear only when routing file explicitly sets ticket_system=Linear.
compatibility: Requires gh CLI, Atlassian MCP (Jira path only).
---

Create a new task in the right system based on where you're working. See `references/routing.md` for routing rules. Once created, the description is frozen — all updates go in comments (see description edit policy in `issue-update`).

**Always use this skill for issue creation — user-initiated or autonomous.** If Claude is about to call `gh issue create` or `glab issue create` directly for any reason (triage, research, session-close, batch work), route through this skill instead. Direct CLI calls bypass routing, label seeding, task index, and project assignment.

## Steps

### 1. Detect routing target

**Explicit repo override (SR-847, SR-901):** If the user's request names a specific repo (e.g. "in claude-skills", "in MichaelHeaton/workstation-devops"), that repo takes precedence over `detect-context.sh` output — skip the script and route directly to the named repo. Only run `detect-context.sh` when no repo is named. When running the script for a named repo that differs from Claude's CWD, `cd` to that repo's directory first (or the script will return the wrong target).

**Explicit Jira override (SR-840):** If the user explicitly says "jira", provides a Jira-style key (e.g. `PROJ-123` or an ALL-CAPS-NNN pattern), or pastes a URL matching the configured Jira instance hostname, route to Path A regardless of what `detect-context.sh` returns. Explicit intent always wins over script output.

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

**De-dupe check (SR-928):** Before drafting, run a quick keyword search in the target system using the proposed title. If 1–3 close matches are found, show them and ask: "Create new, or update an existing one?" If no matches, proceed silently. Skip the check when the user explicitly says "create a new ticket" or has already confirmed uniqueness.

- **Jira (Path A):** `jira_search_issues(jql="project=<key> AND summary ~ \"<keywords>\" AND status != Done ORDER BY created DESC")`
- **GitHub (Path B/C):** `gh issue list --repo <owner/repo> --search "<keywords>" --state open --json number,title,url`
- **Linear (Path D):** Linear MCP `list_issues` with `query: "<keywords>"`

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

### A4. Link to predecessor (if this ticket is a follow-on)

If this ticket was split from or prompted by an existing ticket, establish the relationship in both directions.

**Known gap**: The Atlassian MCP does not expose the `/rest/api/2/issueLink` endpoint — `issuelinks` is rejected as unsupported in `jira_update_issue`. Native Jira issue links cannot be created from here.

**Workaround (do both):**

1. **In the new ticket's description** — reference the predecessor in the Background section: `"Follow-on to <KEY>. <reason it was split out>."`
2. **Comment on the predecessor** — add a comment via `jira_add_comment` noting the new ticket key and why it was created, so anyone viewing the original ticket can navigate forward.

This gives bidirectional traceability even without native issue links. When the MCP gains issueLink support, replace this with a proper `Relates to` / `is caused by` link.

### A5. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system jira \
  --id "<KEY>" \
  --url "<url>" \
  --title "<title>" \
  --domain work-primary \
  --project "<jira.project_key>"
```

### A6. Confirm

Report: ticket key, URL, epic it was linked to, and predecessor link (if applicable).

---

## Path B — GitHub Issue in current repo

> Use only when `detect-context` returns `github-current:*` or the user explicitly requests a GitHub issue / player report.
>
> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

### B0. Public repo check

```bash
gh repo view <owner/repo> --json isPrivate -q '.isPrivate'
```

If output is `false` (public repo): print `⚠️ Public repo — no internal hostnames, Jira keys, or sensitive details in ticket content.` before proceeding to B1. No blocking gate — just a visible reminder before drafting starts.

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

## Path B2 — GitLab Issue in current repo

> Use when `detect-context` returns `gitlab-current:<namespace/repo>`.

### B2-1. Gather information

- **Title**: imperative verb + clear description
- **Domain**: from `categories/tags.yaml` based on project context
- **Priority**: `high`, `medium`, or `low`

Draft the body using the user story template in §C2.

### B2-2. Create the GitLab issue

```bash
glab issue create \
  --repo <namespace/repo> \
  --title "<title>" \
  --label "priority/<priority>,type/<type>" \
  --description "<rendered user story body>"
```

Labels must be created in GitLab before use. If `glab issue create` fails with a label-not-found error, create the label first:

```bash
glab label create --repo <namespace/repo> --name "priority/<priority>" --color "#d97706"
```

### B2-3. Append to task index

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system gitlab \
  --id "<issue-number>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>"
```

### B2-4. Confirm

Report: issue number, URL, repo, and labels applied.

---

## Path C — GitHub Issue in Memex (default personal path)

> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

### C1. Gather information

- **Title**: imperative verb + clear description
- **Domain**: `adobe`, `uv-cyber`, `homelab`, `learning`, `personal`, `mtb`, or `iot`
- **Priority**: `high`, `medium`, or `low`
- **Due date**: only if explicitly stated
- **Vault note** (optional): if the user's message mentions a vault note path (e.g. `CRM/People/name.md`, `Wiki/...`, a Memex path) or a vault note title, capture it now. No need to ask — detect passively from the message.

If the request is vague, ask one clarifying question.

### C2. Draft the issue body (user story template)

See [references/user-story-template.md](references/user-story-template.md) for the full template and role rules.

If a vault note was detected in C1, append a `Related note` line at the bottom of the issue body before creation:

```markdown
---
**Related note:** `<vault-note-path-or-title>`
```

### C3. Create the GitHub Issue

```bash
gh issue create \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --title "<title>" \
  --label "domain/<domain>,priority/<priority>" \
  --body "<rendered user story body>"
```

Capture the returned URL and extract the issue number.

### C3.5. Back-link the vault note (if applicable)

If a vault note was detected in C1 and the note file exists on disk:

1. Read the vault note file
2. If it has a `## GitHub Issues` or `## Related` section, append a line: `- [#NNN — <title>](<url>)`
3. If no such section exists, append one at the end of the file
4. If the vault note path was approximate (title only), skip this step and mention it in C7

Do not block or fail the issue creation if the vault note cannot be found — the issue is the primary artifact.

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

Report: issue number and URL as a markdown link, project it was added to (or skipped with reason), labels applied, and vault note link status (if applicable).

- Normal: `"Created [#97 — Review HomeLab DNS config](https://github.com/...) → HomeLab project, priority/medium."`
- With vault note linked: `"Created [#97 — ...](https://github.com/...) → HomeLab project, priority/medium. Linked in vault note: CRM/People/jane.md."`
- Vault note not found: `"Created [#97 — ...](https://github.com/...) — vault note 'jane.md' not found on disk; add the issue link manually."`
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

---

## Batch creation (SR-910)

When creating 3+ issues at once, parallel `gh issue create` calls are fine for speed — but the task index must be updated for every issue. Skipping this leaves the next session blind.

**Pattern:**

1. Run all `gh issue create` calls in parallel, capturing each returned URL and number.
2. After all issues are created, run the task index append for each one sequentially:

```bash
bash ~/.claude/skills/issue-create/scripts/append-task-index.sh \
  --system github --repo "<owner/repo>" \
  --id "<NUMBER>" --url "<url>" \
  --title "<title>" --domain "<domain>"
```

3. Verify all IDs appear in the index before confirming to the user.

Even when the full per-issue skill flow is skipped for parallelism, the task index step is never optional. A missing entry means the issue won't surface in session-close or open-ticket reviews.
