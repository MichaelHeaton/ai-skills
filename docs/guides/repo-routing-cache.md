---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-30
updated_by: human
---

# Repo routing cache (Notion → local JSON)

## Source of truth

**Notion `Repositories` database** holds `Ticket System`, `Linear Project`, `Projects dest`, and `Clone scope` per repo. Ticket/routing fields: edit in Notion. Clone paths: exported from workstation-devops (see that repo’s `docs/repo-registry-notion.md`).

`detect-context.sh` cannot call Notion MCP. It reads an optional **private cache**:

```text
~/.config/ai-skills/repo-routing.json
```

Never commit the filled cache. Shape-only example: `config/repo-routing.example.json`.

## When the cache is missing

`detect-context.sh` falls back to **built-in heuristics** (repo name prefixes like `homelab-*`, `minecraft-modpack-*`, and a few well-known repo names). Unknown personal repos default to Linear **Personal**.

Agents with Notion MCP should fetch the Repositories DB when routing is ambiguous or heuristics may be wrong.

## Refresh the cache (agent procedure)

Run after adding or changing repos in Notion:

1. Fetch the Repositories data source (`notion.fetch` on your `collection://…` ID).
2. For each row, read `Name`, `Ticket System`, `Linear Project`, and `userDefined:URL` (GitHub URL).
3. Build JSON in this shape and write to `~/.config/ai-skills/repo-routing.json` (mode `600`).
4. Spot-check: `bash ~/.claude/skills/issue-create/scripts/detect-context.sh` from a few repo directories.

Example JSON:

```json
{
  "version": 1,
  "notion_data_source": "collection://…",
  "synced_from": "notion",
  "synced_at": "YYYY-MM-DD",
  "defaults": {
    "no_remote": { "ticket_system": "Linear", "linear_project": "Personal" }
  },
  "repos": {
    "OWNER/repo-name": {
      "ticket_system": "Linear",
      "linear_project": "Homelab"
    }
  }
}
```

## Override path

```bash
export REPO_ROUTING_FILE=/path/to/alternate.json
```

## Related

- `ai/claude/skills/issue-create/references/routing.md` — routing targets and Linear project map
- `config/local.template.json` — `notion.repositories_data_source`, `linear.team`
