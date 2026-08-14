---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: skill-staleness-check
description: Build a scannable list of local, file-based skills (SKILL.md, used via Claude Code) with their version signal (frontmatter version, last_updated, content hash), to compare against what's uploaded and enabled in claude.ai's web/desktop Skills store. Use when asked "are my skills up to date on the web", "check if I need to re-upload any skills", or "which skills have drifted from claude.ai". Note: this skill prepares the local half of the comparison automatically; matching against the web store's actual state currently needs a manual check against the claude.ai Skills UI, since there's no verified API/CLI for reading that store's state from here.
compatibility: Requires local read access to `.claude/skills/` (or the project-scoped equivalent).
---

# Skill Staleness Check

Local, file-based skills (this repo's `ai/claude/skills/`, deployed to `~/.claude/skills/`) and skills uploaded to claude.ai's web/desktop Skills store are two independent copies once uploaded — editing the local file doesn't update the web copy automatically. This skill builds the comparison list; **the web-store side of the comparison is a manual check today**, since there's no verified programmatic way to read the web store's state from this environment. Don't claim an automated match against the web UI — build the local list, then prompt the user to check it against what they see there.

## 1. Enumerate local skills

```bash
for f in ~/.claude/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  version=$(grep -m1 '^version:' "$f" | awk '{print $2}')
  updated=$(grep -m1 '^last_updated:' "$f" | awk '{print $2}')
  hash=$(sha256sum "$f" | cut -c1-12)
  echo "$name|$version|$updated|$hash"
done
```

This gives every local skill's version marker (frontmatter `version` + `last_updated`) and a content hash — the hash is what actually changed, since `version`/`last_updated` are only as accurate as whoever last bumped them.

## 2. Present the comparison list

Output a short, scannable table — not a wall of individual diffs:

```
| Skill | Local version | Last updated | Content hash |
| --- | --- | --- | --- |
| git-ops | 1.17.0 | 2026-08-14 | a1b2c3d4e5f6 |
| issue-create | 1.10.1 | 2026-08-14 | 9f8e7d6c5b4a |
```

## 3. Manual verification against the web store

Ask the user to open claude.ai's Skills settings and check each skill's uploaded version/date against this table. Flag any mismatch they report as:

- **Stale** — web copy is older than local; re-zip and re-upload
- **Current** — matches
- **Unknown** — not uploaded to the web store at all (local-only skill), or the web UI doesn't expose a comparable version marker for it

## 4. Report

```
✓ 12 skills current
✗ 3 skills stale — re-upload: git-ops, issue-create, session-close
? 5 skills local-only, not on the web store
```

If a future session confirms a reliable way to read the web store's state programmatically (an API, an export file), fold step 3 into an automated diff and update this skill — until then, don't guess at an interface that hasn't been verified.
