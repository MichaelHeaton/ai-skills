---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-15
updated_by: claude
name: memory-rollback
description: List prior snapshots of a project's memory file (~/.claude/projects/<project-hash>/memory/*.md) and restore a chosen one on user confirmation. Snapshots come from the opt-in memory-snapshot hook, which auto-commits each edit to a local git repo in the memory directory. Use when the user says "restore my memory", "undo that memory edit", "what changed in memory", "list memory snapshots", "roll back this memory file", "revert my memory notes", or when a memory file edit looks wrong and needs to be undone. Requires the memory-snapshot hook to have been enabled (via update-config) and to have already produced at least one snapshot — without that, there is nothing to list or restore.
compatibility: Requires git. Requires the ai/claude/hooks/memory-snapshot.py hook to be enabled via the update-config skill.
---

# Memory Rollback

Restore a project's memory file to an earlier state, using the git snapshots
that the opt-in `memory-snapshot` hook auto-commits on every edit.

**This skill only works if snapshots exist.** The `memory-snapshot` hook is
NOT wired into any tracked `settings.json` by default — it must be enabled
first via the `update-config` skill (`ai/claude/hooks/memory-snapshot.py`,
`PostToolUse`, matcher `Edit|Write`). If no `.git` directory exists in the
memory directory, no snapshots were ever taken; say so and stop.

## 1. Identify the target file

Ask which memory file to roll back if not already named, and confirm the
memory directory path: `~/.claude/projects/<project-hash>/memory/<file>.md`.

If the project hash isn't known, look for the memory directory under
`~/.claude/projects/*/memory/` that contains the named file.

## 2. List available snapshots

Run the helper script against the memory directory and filename:

```
bash ai/claude/skills/memory-rollback/scripts/list-snapshots.sh \
  ~/.claude/projects/<project-hash>/memory <file>.md
```

This prints each commit as `<rev>:<iso-date>:<subject>`, newest first. If the
script reports no git repo or no such file, tell the user there is nothing
to roll back and stop here — do not attempt manual git commands as a
fallback, since that would create snapshots outside the hook's control.

Present the list to the user in a readable form (date and subject are
usually enough — only show the short rev if they ask to see it).

## 3. Confirm which snapshot to restore

Ask the user to pick a specific snapshot from the list (by date or by
position, e.g. "the one from 2 days ago"). Do not guess or auto-select the
most recent prior snapshot — restoring the wrong version is a real cost, and
the whole point of showing the list is to let the user choose.

## 4. Restore the chosen snapshot

Restore is a **forward commit, not a history rewrite** — never use
`git reset`. From the memory directory:

```
git -C ~/.claude/projects/<project-hash>/memory checkout <rev> -- <file>.md
git -C ~/.claude/projects/<project-hash>/memory commit -m "restore: <file>.md to <rev>"
```

This checks the old content back out into the working tree, then commits
that restored state as a brand-new commit at the tip of the log. The
snapshot history stays intact — the commit being restored from, and every
commit made since it, is still there and inspectable, so a restore can
itself be rolled back the same way if the user picked wrong.

## 5. Confirm the result

Tell the user which snapshot was restored and that the restore itself was
committed (so it shows up in a future `list-snapshots.sh` run). Do not
modify any other memory file or any file outside the target memory
directory.
