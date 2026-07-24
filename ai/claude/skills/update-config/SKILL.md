---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: update-config
description: Add or remove allowed tools and permissions in Claude Code settings.json. Routes each permission to the correct scope — global (~/.claude/settings.json) for skill scripts, cross-repo CLI tools, and general utilities; project (.claude/settings.json) for repo-specific paths. Use when adding a new allow-list entry, granting a tool permission, "add this to settings", "allow this command", "update my Claude config", "add to allowlist", or "grant permission for".
compatibility: Requires write access to ~/.claude/settings.json and/or .claude/settings.json.
---

# Update Config

Add or remove Claude Code permissions in the right settings file. Routing matters — skill and global tool permissions written to a project's `.claude/settings.json` accumulate silently across sessions and end up in the wrong repo.

## Routing rules

Classify the permission first, then write to the correct file:

| Pattern | Target | Example |
| --- | --- | --- |
| `~/.claude/skills/` path | **Global** | `~/.claude/skills/session-close/scripts/discover-repos.sh` |
| `~/.claude/` path (any) | **Global** | `~/.claude/hooks/post-run.sh` |
| General CLI tools | **Global** | `yamllint`, `shellcheck`, `glab`, `jq`, `gh`, `git` |
| Paths inside current repo | **Project** | `./scripts/run-tests.sh`, `/home/user/myrepo/scripts/build.sh` |
| Ambiguous or cross-repo | **Global** | When in doubt, global keeps project settings clean |

**Always tell the user which file you're writing to and why.**

Example routing messages:

- `Writing to global settings (~/.claude/settings.json) — skill script paths apply across all repos.`
- `Writing to global settings — yamllint is a general-purpose tool, not repo-specific.`
- `Writing to project settings (.claude/settings.json) — this path is inside the current repo.`

## Steps

### 1. Classify the permission

Read the permission string the user wants to add. Apply routing rules above. If the path starts with `~/` or `/home/<user>/.claude/` or matches a well-known CLI name, route to global. If it contains the current repo's working directory path, route to project.

### 2. Read the target settings file

```bash
cat ~/.claude/settings.json          # global
cat .claude/settings.json            # project (if it exists)
```

If the target file does not exist, start from `{"allowedTools": []}`.

### 3. Check for duplicates

If the permission already exists in the target file, report it and stop — no write needed.

If the permission exists in the *other* file (e.g., in project when it should be global), offer to migrate:

> **This permission is in project settings but should be global. Move it?**
>
> - **Yes, move to global** — remove from project, add to global
> - **Leave as-is** — keep current location

### 4. Write the updated settings

Add the permission to `allowedTools` (for tool allow-list entries) or the appropriate key. Write the updated JSON back.

For global settings:

```bash
# Read, update, write atomically
python3 -c "
import json, sys
path = '$HOME/.claude/settings.json'
try:
    data = json.load(open(path))
except FileNotFoundError:
    data = {}
data.setdefault('allowedTools', [])
entry = sys.argv[1]
if entry not in data['allowedTools']:
    data['allowedTools'].append(entry)
    json.dump(data, open(path, 'w'), indent=2)
    print('added')
else:
    print('already present')
" "<permission>"
```

### 5. Confirm

Report:

- What was added
- Which file it was written to
- Why (one short phrase)

Example: `✓ Added 'Bash(~/.claude/skills/*)' → global settings. Skill paths apply across all repos.`
