---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: cross-repo-ticket-router
description: Detect when a ticket's actual fix location resolves — via a symlink, a monorepo layout, or a deployed-copy convention — to a different repo than the one it was filed in, before spending effort implementing in the wrong place. Use before starting work on any ticket whose subject is a symlinked or deployed artifact (skills under ~/.claude/skills/, configs deployed from a source repo, vendored code), or whenever a fix "isn't taking effect" after an edit that looked correct. Triggers on "why isn't this change showing up", "check if this is the real source", "is this the actual file or a copy", or at the start of issue-triage/dev-team/issue-create when a ticket names a path that might be a deploy target.
compatibility: Requires git.
---

# Cross-Repo Ticket Router

A ticket filed against one repo can have its real fix location in a different one — most often because the path named in the ticket is a deployed copy or symlink, not the source. Editing the copy silently does nothing; the next deploy overwrites it.

**Generalizes** dev-team's own cross-repo fix-location check (added for its pipeline specifically) to any workflow that starts from a ticket: issue-triage, issue-create's de-dupe search, or ad hoc work outside a formal pipeline.

## 1. Recognize the shape

A ticket is a candidate for this check when its subject matter is:

- A path under a known deploy target (`~/.claude/skills/`, `~/.claude/agents/`, `~/.cursor/rules/` — anything a `make install-system`-style step populates)
- Part of a monorepo where the visible directory is a subtree pulled from elsewhere
- Described as behaving differently after a "fix" that should have taken effect

## 2. Resolve the real source

```bash
readlink -f <path-named-in-ticket>
```

If the resolved path is a **different directory** than the repo the ticket was filed in — most commonly the symlink target lands in `ai-skills`'s checkout rather than the consuming repo — the fix belongs there, not in the repo the ticket lives in.

For a monorepo subtree (no symlink, but the directory is a synced/vendored copy), check for a marker file (`.git`, a `SOURCE` pointer, a README noting "generated from") rather than assuming a symlink is the only signal.

## 3. Surface the mismatch

Don't silently redirect and start editing the other repo without saying so. Tell the user (or, inside an automated pipeline, the calling skill):

```
Ticket names ~/.claude/skills/git-ops/SKILL.md, which resolves to
~/Projects/personal/ai-skills/ai/claude/skills/git-ops/SKILL.md — the
actual fix location is ai-skills, not this repo.
```

If the target repo isn't already available in the current session (no local checkout, no attached remote), say that explicitly rather than guessing at a fix in the wrong place — this mirrors the "don't guess-attach a repo, ask" discipline used elsewhere for genuinely cross-repo tickets.

## 4. Route

Once confirmed, hand off to whatever's actually implementing the fix (a plain edit, `dev-team`, `issue-create` for a redirect ticket) targeting the resolved repo — not the one the ticket happened to be filed in.
