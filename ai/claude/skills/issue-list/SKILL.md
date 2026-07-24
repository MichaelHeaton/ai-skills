---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
name: issue-list
description: Get a list of open tasks/tickets — across all systems (Linear, GitHub, Jira) or scoped to a project, label, or priority. Always syncs status back to the task index.
---

Fetch open tasks from all active systems, sync any status changes back to the task index, then present results.

## Steps

### 0. Set personal GitHub token

The active `gh` account may be a work account that cannot access personal repos. Set `GITHUB_PERSONAL_USER` in `~/.zshrc` (your personal GitHub username), then export the personal token before any GitHub call:

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

### 1. Sync closed issues → task index

**Linear:** `list_issues` with `assignee: "me"`, `team` from `linear.team` in local.json. Sync completed/canceled issues to index (`system: linear`).

**GitHub:** Find index records still `open` that GitHub closed (group by `repo` from index, not only memex):

```bash
python3 << 'EOF'
import json, os, subprocess

index_path = os.path.expanduser("~/Projects/personal/memex/Raw/_task-index.jsonl")
github_user = os.environ.get("GITHUB_PERSONAL_USER", "")

with open(index_path) as f:
    records = [json.loads(l) for l in f if l.strip()]

open_github = {r["id"]: r for r in records if r.get("system") == "github" and r.get("status") == "open"}

if not open_github:
    print("No open GitHub issues in index.")
else:
    result = subprocess.run(
        ["gh", "issue", "list",
         "--repo", f"{github_user}/memex",
         "--state", "closed",
         "--json", "number,title",
         "--limit", "200"],
        capture_output=True, text=True
    )
    closed_on_github = {str(i["number"]) for i in json.loads(result.stdout)}

    newly_closed = [id_ for id_ in open_github if id_ in closed_on_github]

    if newly_closed:
        updated = []
        for line in open(index_path):
            d = json.loads(line)
            if d.get("system") == "github" and d.get("id") in newly_closed:
                d["status"] = "closed"
            updated.append(json.dumps(d))
        with open(index_path, "w") as f:
            f.write("\n".join(updated) + "\n")
        for id_ in newly_closed:
            print(f"  Synced closed: #{id_} — {open_github[id_]['title']}")
    else:
        print("All open GitHub issues still open — index up to date.")
EOF
```

Report any synced closures before presenting the list.

### 2. Query live systems

**Linear (default personal backlog):** `list_issues` with `team` from local.json, `assignee: "me"`. Filter by `project` when scoped.

**GitHub Issues — repo-scoped** (when user asks about GitHub issues in a repo):

```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
# If github-current:<owner/repo>:
gh issue list --repo <owner/repo> --state open --json number,title,labels,url --limit 100
```

**Work Jira (via Atlassian MCP):**
Use JQL: `assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC`
See [[Agents/23-jira-rules|23-jira-rules]] for ticket type conventions and work Jira context (private vault rules).

### 3. Catch unindexed issues

If any system returns an issue number not present in the index, append a new record using the schema in [[Agents/22-task-index|22-task-index]].

### 4. Present results

Group by domain. For each open task show:

- Issue/ticket ID and title as a markdown link
- Priority label
- URL

**Example output format:**

```
## Homelab
- [SR-12](url) Review DNS config [medium]
- PROJ-12345 — Document security ticket timeline delays
```

### 5. Optional filters

If the user specifies a domain, project, system, or label, filter before presenting:

**By domain/system:**

- "show me my work tasks" → `domain: work-primary`
- "what's open in HomeLab" → `project: HomeLab`
- "my Linear tasks" → `system: linear`
- "my Jira tickets" → `system: jira`

**By label (pass to `--label` in the `gh` call, or filter post-fetch for Jira):**

- "show me the bugs" / "type/bug issues" → `--label type/bug`
- "high priority" / "what should I work on" → `--label priority/high`
- "high or medium priority" → fetch with no label filter, then filter results for both
- "high priority bugs" → `--label type/bug`, then filter results for `priority/high`
- "what's blocking" → `--label type/bug,priority/high` or look for `blocked` label

When the user's intent is to pick work for the current session, default to showing `priority/high` and `priority/medium` items first, with `priority/low` collapsed or omitted unless asked.
