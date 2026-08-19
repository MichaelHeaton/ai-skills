---
version: 2.1.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: issue-create
description: Create a new task, issue, or story in the right system — GitHub Issues (Memex) or Jira — based on the current repo context. Handles template, routing, project assignment, issues log, and task index automatically. Use when the user asks to create a task, capture an action item, add something to the backlog, "log this as an issue", "make a ticket for", "create a story for", "this should be its own ticket", "separate ticket for X", "let's decompose", "track this for later", or similar. Also fires autonomously — always use this skill when Claude itself decides to create any issue (during triage, research, session-close, or any workflow), when creating multiple issues in a batch, or whenever about to call gh issue create or glab issue create directly, or whenever about to call a ticketing MCP tool directly such as jira_create_issue (Jira). Work org remotes → Jira Story; everything else → GitHub Issue (current repo, or Memex when no repo context).
compatibility: GitHub paths (B/C) prefer gh CLI; fall back to mcp__github__* MCP tools when gh is unavailable — see references/gh-mcp-fallback.md. Jira path (A) requires Atlassian MCP; if it's unreachable rather than merely absent, see references/atlassian-mcp-fallback.md. Memex path (C) writes to a local vault clone when present, skips gracefully with a warning when not.
---

Create a new task in the right system based on where you're working. See `references/routing.md` for routing rules. Once created, the description is frozen — all updates go in comments (see description edit policy in `issue-update`).

**Always use this skill for issue creation — user-initiated or autonomous.** If Claude is about to call `gh issue create` or `glab issue create` directly, or call a ticketing MCP tool directly such as `jira_create_issue` (Jira) (triage, research, session-close, batch work), route through this skill instead. Direct CLI or MCP tool calls bypass routing, label seeding, task index, and project assignment.

**This instruction is easiest to skip in a long, tool-heavy session** — not because the wording is unclear, but because "always route through this skill" competes with dozens of other tool calls for attention as a session goes on, and it's been observed being followed for some creates in a session while skipped for others in the same session. Before any direct `gh issue create`/`glab issue create`/`jira_create_issue` call, treat it as a one-beat check: "should this go through issue-create instead?" — the same way git-ops's frontmatter reminds against proceeding from memory on a stale invocation.

**Run to completion once triggered.** Once this skill starts, execute every step through to confirmation before returning to other work — don't let an unrelated question or investigation mid-flow pull focus away with the ticket half-created. If execution genuinely must pause (a missing field only the user can supply, a tool failure), say so explicitly rather than silently drifting into other tasks and leaving the user to guess whether the ticket exists.

## Steps

### 0. Environment setup

Resolve the skill's own script directory once, before running any script below — deployment layout varies (flat `~/.claude/skills/issue-create/` vs. `~/.claude/skills/synced/issue-create/`), and a hardcoded path silently fails in the other layout:

```bash
SKILL_DIR="$HOME/.claude/skills/issue-create"
[[ -d "$SKILL_DIR/scripts" ]] || SKILL_DIR="$HOME/.claude/skills/synced/issue-create"
```

Use `"$SKILL_DIR/scripts/<name>.sh"` for every script invocation below instead of a literal path.

**gh CLI availability** — some environments (cloud/web sessions) have no `gh`/`hub` binary at all, only `mcp__github__*` MCP tools:

```bash
command -v gh >/dev/null 2>&1 && echo present || echo absent
```

If absent, every `gh`-dependent step below (de-dupe check, B0, B2–B5, C3, C4, C7) has an MCP equivalent — see [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md). Jira (Path A) already uses MCP tools exclusively and is unaffected.

### 1. Detect routing target

**Explicit repo override (SR-847, SR-901):** If the user's request names a specific repo (e.g. "in claude-skills", "in MichaelHeaton/workstation-devops"), that repo takes precedence over `detect-context.sh` output — skip the script and route directly to the named repo. Only run `detect-context.sh` when no repo is named. When running the script for a named repo that differs from Claude's CWD, `cd` to that repo's directory first (or the script will return the wrong target).

**Explicit Jira override (SR-840):** If the user explicitly says "jira", provides a Jira-style key (e.g. `PROJ-123` or an ALL-CAPS-NNN pattern), or pastes a URL matching the configured Jira instance hostname, route to Path A regardless of what `detect-context.sh` returns. Explicit intent always wins over script output.

```bash
bash "$SKILL_DIR/scripts/detect-context.sh"
```

The output tells you which path to follow:

- `jira-work` → Path A (Jira Story)
- `github-current:<owner/repo>` → Path B (GitHub Issue in that repo)
- `memex` → Path C (GitHub Issue in Memex)
- `gitlab-current:<namespace/repo>` → Path B2 (GitLab Issue)

**Player / tester / playtest reports:** set `export ISSUE_ROUTE=github` before detect-context, or use Path B when the user explicitly asks for a GitHub issue.

**Voice transcription aliases**: If the repo name sounds like a voice transcription artifact, confirm with the user before routing.

**De-dupe check (SR-928):** Before drafting, run a quick keyword search in the target system using the proposed title. If 1–3 close matches are found, show them and ask: "Create new, or update an existing one?" If no matches, proceed silently. Skip the check when the user explicitly says "create a new ticket" or has already confirmed uniqueness.

- **Jira (Path A):** `jira_search_issues(jql="project=<key> AND summary ~ \"<keywords>\" AND status != Done ORDER BY created DESC")`
- **GitHub (Path B/C):** `gh issue list --repo <owner/repo> --search "<keywords>" --state open --json number,title,url` (no `gh`? see [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md))

---

## Path A — Jira (work)

Read `jira.*` from `~/.config/ai-skills/local.json` before creating issues.

**Atlassian MCP unreachable?** This path has no CLI fallback the way GitHub paths fall back from `gh` to `mcp__github__*` — a connection/auth/timeout failure on `jira_get_project_components` or `jira_create_issue` (as opposed to a normal Jira API error) means the ticket was not created. Don't proceed as if it was. See [references/atlassian-mcp-fallback.md](references/atlassian-mcp-fallback.md) for the surface-and-choose sequence: defer, or fall back to a GitHub Issue as a placeholder.

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

**Two known Jira MCP corruption modes — both need the same verify-then-fix loop.** (For the fuller pre-check + auto-fix version of this loop, including Confluence and batch correction of already-corrupted tickets, see the `ticket-write-verify` skill _(global: ai-skills)_.) (1) Underscore-escaping survives backtick/monospace wrapping: Jira's create/update API escapes underscores in identifiers (resource names, variable names) into `\_` — even when the identifier is wrapped in backticks or `{{...}}` monospace markers; that formatting is not a reliable workaround. (2) Bracket-style tags in prose get silently stripped: a marker like `[STEP]` used as a step-name label can come back as `STEP` with the brackets gone, likely because the API reads it as malformed link syntax. Both have recurred together in the same session's create/update calls. After creating (or updating) an issue, verify the rendered result via `jira_get_issue` and correct via a follow-up `jira_update_issue` (or `jira_edit_comment` for comments) if either pattern shows up mangled.

Create via Atlassian MCP `jira_create_issue` with `jira.project_key`, the component from A2 (if applicable), and the multi-line description.

If the description carries a narrative justification rather than just a task statement (e.g. explaining _why_ scope changed, defending a timeline), run it through `doc-coauthor`'s consistency-audit stage _(global: ai-skills)_ first — the same verdict-before-evidence and repeated-rebuttal failure modes that hit long-form docs show up in ticket narratives too.

### A4. Link to predecessor (if this ticket is a follow-on)

If this ticket was split from or prompted by an existing ticket, establish the relationship in both directions.

**Known gap**: The Atlassian MCP does not expose the `/rest/api/2/issueLink` endpoint — `issuelinks` is rejected as unsupported in `jira_update_issue`. Native Jira issue links cannot be created from here.

**Workaround (do both):**

1. **In the new ticket's description** — reference the predecessor in the Background section: `"Follow-on to <KEY>. <reason it was split out>."`
2. **Comment on the predecessor** — add a comment via `jira_add_comment` noting the new ticket key and why it was created, so anyone viewing the original ticket can navigate forward.

This gives bidirectional traceability even without native issue links. When the MCP gains issueLink support, replace this with a proper `Relates to` / `is caused by` link.

### A5. Append to task index

```bash
bash "$SKILL_DIR/scripts/append-task-index.sh" \
  --system jira \
  --id "<KEY>" \
  --url "<url>" \
  --title "<title>" \
  --domain work-primary \
  --project "<jira.project_key>"
```

### A5.5. Freshness re-check (optional, cheap)

The de-dupe check in "Detect routing target" only searches _before_ creation — it can't catch activity that lands on the ticket's own key right after it's created (a webhook-driven comment, an automation-added field). Before finalizing the confirmation message, do one fresh `jira_get_issue` fetch on the ticket just created. If it already carries comments or field changes that weren't part of the draft in A3, surface them in the A6 confirmation instead of confirming as if the ticket were still exactly as drafted.

### A6. Confirm

Report: ticket key, URL, epic it was linked to, predecessor link (if applicable), and any unexpected activity found in the A5.5 freshness re-check.

---

## Path B — GitHub Issue in current repo

> Use only when `detect-context` returns `github-current:*` or the user explicitly requests a GitHub issue / player report.
>
> **Account:** `export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")`

### B0. Public repo check

```bash
gh repo view <owner/repo> --json isPrivate -q '.isPrivate'
```

No `gh`? See [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md) for the MCP equivalent.

If output is `false` (public repo): print `⚠️ Public repo — no internal hostnames, Jira keys, or sensitive details in ticket content.` before proceeding to B1. No blocking gate — just a visible reminder before drafting starts.

### B1. Gather information

- **Title**: imperative verb + clear description
- **Type or Domain**:
  - `ai-skills` repo → **type**: `new-skill`, `enhancement`, `bug`, or `review`
  - Other repos → **domain** from `categories/tags.yaml`
- **Priority**: `high`, `medium`, or `low`

Draft the body using the user story template in §C2.

### B2–B5

Seed labels, `gh issue create`, append task index with `--system github`. Before confirming, same freshness re-check as Path A's A5.5: `gh issue view <NUMBER> --repo <owner/repo> --json comments,updatedAt` — surface anything unexpected in the confirmation rather than confirming silently.

No `gh`? See [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md) for the `mcp__github__*` equivalents of both calls.

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
bash "$SKILL_DIR/scripts/append-task-index.sh" \
  --system gitlab \
  --id "<issue-number>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>"
```

### B2-4. Confirm

Before confirming, same freshness re-check as Path A's A5.5: `glab issue view <NUMBER> --repo <namespace/repo>` — surface anything unexpected in the confirmation rather than confirming silently.

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

No `gh`? See [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md).

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

No MCP equivalent exists for GitHub Projects (v2) — when `gh` is unavailable, skip this step the same way as the missing-scope case below and report it in C7.

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
bash "$SKILL_DIR/scripts/append-task-index.sh" \
  --system github \
  --repo "${GITHUB_PERSONAL_USER}/memex" \
  --id "<NUMBER>" \
  --url "<url>" \
  --title "<title>" \
  --domain "<domain>" \
  --project "<Project Name>"
```

### C7. Confirm

Before confirming, same freshness re-check as Path A's A5.5: `gh issue view <NUMBER> --repo ${GITHUB_PERSONAL_USER}/memex --json comments,updatedAt` — surface anything unexpected in the confirmation rather than confirming silently. No `gh`? See [references/gh-mcp-fallback.md](references/gh-mcp-fallback.md).

Report: issue number and URL as a markdown link, project it was added to (or skipped with reason), labels applied, and vault note link status (if applicable).

- Normal: `"Created [#97 — Review HomeLab DNS config](https://github.com/...) → HomeLab project, priority/medium."`
- With vault note linked: `"Created [#97 — ...](https://github.com/...) → HomeLab project, priority/medium. Linked in vault note: CRM/People/jane.md."`
- Vault note not found: `"Created [#97 — ...](https://github.com/...) — vault note 'jane.md' not found on disk; add the issue link manually."`
- Project add skipped: `"Created [#97 — ...](https://github.com/...) — not added to project (missing read:project scope; run \`gh auth refresh -s read:project\` to fix), priority/medium."`

---

## Batch creation (SR-910)

When creating 3+ issues at once, parallel `gh issue create` calls are fine for speed — but the task index must be updated for every issue. Skipping this leaves the next session blind.

**Pattern:**

1. Run all `gh issue create` calls in parallel, capturing each returned URL and number.
2. After all issues are created, run the task index append for each one sequentially:

```bash
bash "$SKILL_DIR/scripts/append-task-index.sh" \
  --system github --repo "<owner/repo>" \
  --id "<NUMBER>" --url "<url>" \
  --title "<title>" --domain "<domain>"
```

1. Verify all IDs appear in the index before confirming to the user.

Even when the full per-issue skill flow is skipped for parallelism, the task index step is never optional. A missing entry means the issue won't surface in session-close or open-ticket reviews.

---

## Optional: automated reminder hooks

"Always route through this skill" (frontmatter, above) is easy to follow for the first ticket of a session and drift away from later — the exact gap this section's own risk callout describes: one ticket created correctly through the skill, later near-identical tickets created via a direct `jira_create_issue`/`save_issue`/`gh issue create`/`glab issue create` call instead, with the dedupe-search and task-index steps either skipped or manually replicated. Two companion hooks close this gap without blocking anything, mirroring `git-ops`'s own `git-ops-track.py`/`git-ops-reminder.py` pattern:

- `hooks/issue-create-track.py` (`PostToolUse`, matcher `Skill`) — records that issue-create fired, once per session
- `hooks/issue-create-reminder.py` (`PreToolUse`) — prints a one-line nudge before a direct `gh issue create` / `glab issue create` Bash command, or a direct `jira_create_issue` / `save_issue` MCP tool call, if issue-create hasn't fired yet this session

Both are advisory only (always exit 0) and never block a command. They aren't wired into any tracked `settings.json` by default — this repo has no mechanism to write to a user's live `~/.claude/settings.json` on their behalf, so making them default-on isn't something a PR here can actually deliver. If this gap has bitten you before, the fix is cheap: add them via the `update-config` skill now rather than waiting for a repeat.

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Skill", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/issue-create-track.py" }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/issue-create-reminder.py" }] },
      { "matcher": "mcp__.*jira_create_issue", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/issue-create-reminder.py" }] },
      { "matcher": "mcp__.*save_issue", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/issue-create-reminder.py" }] }
    ]
  }
}
```

**Why three `PreToolUse` matchers, not one:** `gh issue create`/`glab issue create` arrive as `Bash` commands, so the hook reads `tool_input.command`. `jira_create_issue`/`save_issue` arrive as direct MCP tool calls with no shell command to inspect — the hook instead matches on the tool name itself, which the `Bash` matcher can't see. The exact MCP server prefix (`mcp__atlassian__...`, `mcp__linear__...`, etc.) varies by environment, so the matcher regex anchors on the method name suffix rather than a hardcoded prefix.
