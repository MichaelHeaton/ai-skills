---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: vet-installer-side-effects
description: Before letting a third-party CLI/skill installer run, or before trusting its result, read its actual source (hooks, CLI entry points) and diff what it changed against what was explicitly approved — an installer can silently add hooks, edit CLAUDE.md, or touch settings beyond the scope the user agreed to. Use before running any third-party installer command against .claude/ or similar config directories, or right after running one, when asked "check what this installer actually did", "did that tool add anything I didn't approve", or "vet this before I trust it".
compatibility: Requires read access to the installer's source and the config files it might touch.
---

# Vet Installer Side Effects

An installer command can do more than what was approved in the moment — "register the skill, project-scoped" is a specific, narrow ask, but the installer's actual behavior might also wire hooks into every tool call or edit CLAUDE.md to add its own instructions, none of which were called out as separate asks. The approval covered one thing; the installer did several.

## 1. Before running — read the installer's source, not just its docs

If the installer is a package with inspectable source (not a closed binary), read its actual implementation before running it — the CLI entry point and anything resembling a hooks/config-writer module. Docs describe intended behavior; source describes actual behavior, and the two aren't guaranteed to match.

Specifically look for:

- Writes to `.claude/settings.json` or `~/.claude/settings.json` (hook registration, tool interception)
- Writes to `CLAUDE.md`, `AGENTS.md`, or other AI-context files
- Any `PreToolUse`/`PostToolUse` hook wiring that would route tool calls through the installer's own binary

## 2. After running — diff the actual changes

Regardless of whether source review happened first, diff the config files the installer could plausibly have touched:

```bash
git diff .claude/settings.json CLAUDE.md AGENTS.md 2>/dev/null
```

If these aren't in a git repo, snapshot them before running the installer so a diff is possible after.

## 3. Compare against what was actually approved

Line up each change against the specific thing the user approved. A change that goes beyond it — hook wiring when only a skill registration was approved, a CLAUDE.md edit nobody asked for — needs a separate confirmation, not a silent pass because "the installer probably needed to do that."

## 4. Confirm keep/revert per change

Present each unapproved change individually and let the user decide:

```
Installer also did, beyond what was approved:
1. Added a PreToolUse hook routing Bash/Grep/Read/Glob through its own binary
2. Added a "## Third-party tool" section to CLAUDE.md

Keep both, keep one, or revert both?
```

Don't bundle unrelated changes into one keep/revert decision — a hook wiring change and a doc edit are different risk levels and deserve separate answers.

## 5. Revert cleanly

If reverting, undo exactly the diffed changes — `git checkout -- <file>` if unstaged, or a targeted edit removing just the added section/hook entry if other legitimate changes need to be preserved alongside the revert.
