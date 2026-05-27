---

name: issue-list
description: Get a list of open tasks/tickets — across all systems (GitHub, GitLab, Jira) or scoped to a specific repo, label, or priority. Always syncs status back to the task index. Use during morning review, triage, or when the user asks "what's on my plate", "what are my open tasks", "show me my issues", "show me the bugs", "what high priority issues are open", "filter issues by label", "what issues are in this repo", "what should I work on today", "show me type/bug tickets", "pull the issues for this repo", or similar.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


Fetch open tasks from all active systems, sync any status changes back to the task index, then present results.

## Steps

### 0. Set personal GitHub token

The active `gh` account may be a work account that cannot access personal repos. Set `GITHUB_PERSONAL_USER` in `~/.zshrc` (your personal GitHub username), then export the personal token before any GitHub call:

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
```

### 1. Sync closed GitHub issues → task index

Find any issues the index still shows as `open` that GitHub has since closed:

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

### 2. Sync closed GitLab issues → task index

Find any GitLab issues the index still shows as `open` that GitLab has since closed:

```bash
python3 << 'EOF'
import json, os, subprocess

index_path = os.path.expanduser("~/Projects/personal/memex/Raw/_task-index.jsonl")

with open(index_path) as f:
    records = [json.loads(l) for l in f if l.strip()]

open_gitlab = {r["id"]: r for r in records if r.get("system") == "gitlab" and r.get("status") == "open"}

if not open_gitlab:
    print("No open GitLab issues in index.")
else:
    # Group by repo to minimize API calls
    by_repo = {}
    for id_, r in open_gitlab.items():
        by_repo.setdefault(r["repo"], []).append(id_)

    newly_closed = []
    for repo, ids in by_repo.items():
        result = subprocess.run(
            ["glab", "issue", "list", "--repo", repo,
             "--state", "closed", "--output", "json"],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            closed_iids = {str(i["iid"]) for i in json.loads(result.stdout)}
            newly_closed.extend(id_ for id_ in ids if id_ in closed_iids)

    if newly_closed:
        updated = []
        for line in open(index_path):
            d = json.loads(line)
            if d.get("system") == "gitlab" and d.get("id") in newly_closed:
                d["status"] = "closed"
            updated.append(json.dumps(d))
        with open(index_path, "w") as f:
            f.write("\n".join(updated) + "\n")
        for id_ in newly_closed:
            print(f"  Synced closed: #{id_} — {open_gitlab[id_]['title']}")
    else:
        print("All open GitLab issues still open — index up to date.")
EOF
```

Report any synced closures before presenting the list.

### 3. Query live systems

**GitHub Issues — current repo (when in a specific repo context):**

If the user is asking about a specific repo (e.g. "show me the bugs in this repo", "what issues are open here"), detect the repo first:
```bash
bash ~/.claude/skills/issue-create/scripts/detect-context.sh
# → github-current:<owner/repo>
```

Then query that repo, adding `--label` when the user specifies a filter:
```bash
gh issue list \
  --repo <owner/repo> \
  --state open \
  --json number,title,labels,url \
  --limit 100 \
  [--label <label>]   # e.g. --label type/bug or --label priority/high
```

**GitHub Issues — personal task review (Memex):**
```bash
gh issue list \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --state open \
  --json number,title,labels,url \
  --limit 200
```

**GitLab Issues:** Query each unique repo found in the task index with `system: "gitlab"`:
```bash
glab issue list --repo <namespace/repo> --state opened --output json
```

**Adobe Jira (via Atlassian MCP):**
Use JQL: `assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC`
See [[Agents/23-jira-rules|23-jira-rules]] for ticket type conventions and CES-specific context.

### 4. Catch unindexed issues

If any system returns an issue number not present in the index, append a new record using the schema in [[Agents/22-task-index|22-task-index]].

### 5. Present results

Group by domain. For each open task show:
- Issue/ticket ID and title as a markdown link
- Priority label
- URL

**Example output format:**
```
## Adobe
- [#130](url) Investigate cross-mount secrets access [priority/medium]
- PROJ-XXXXX — Document security ticket timeline delays

## UV Cyber
- [#144](url) Verify CPUID exploit tools not present [priority/high]

## HomeLab
- [#107](url) MCP Tutorial: Connect AI to your HomeLab [priority/low]

## Personal (GitLab)
- [#12](url) Fix spawn rates — minecraft-modpack-cp-verdant
```

### 6. Optional filters

If the user specifies a domain, project, system, or label, filter before presenting:

**By domain/system:**
- "show me my Adobe tasks" → `domain: adobe`
- "what's open in HomeLab" → `project: HomeLab`
- "my Jira tickets" → `system: jira-adobe`
- "my GitLab issues" → `system: gitlab`

**By label (pass to `--label` in the `gh` call, or filter post-fetch for GitLab/Jira):**
- "show me the bugs" / "type/bug issues" → `--label type/bug`
- "high priority" / "what should I work on" → `--label priority/high`
- "high or medium priority" → fetch with no label filter, then filter results for both
- "high priority bugs" → `--label type/bug`, then filter results for `priority/high`
- "what's blocking" → `--label type/bug,priority/high` or look for `blocked` label

When the user's intent is to pick work for the current session, default to showing `priority/high` and `priority/medium` items first, with `priority/low` collapsed or omitted unless asked.
