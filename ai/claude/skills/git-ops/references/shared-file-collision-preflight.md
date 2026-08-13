---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Pre-flight: colliding open PR on a shared file

Before committing a change to a file that's shared and frequently touched across sessions, check for an existing open PR against it first. `.claude/settings.json` was the original motivating example, but skill `SKILL.md` files (and their `references/*.md`) are the more frequent recurring offender in practice — two concurrent sessions editing the same skill's docs within moments of each other is the more common collision, not just the settings file:

```bash
gh pr list --search "<file-path-or-filename>" --state open --repo <owner>/<repo>
```

If an open PR already touches that file, fold the new content into it or wait for it to merge, rather than proposing an independent, likely-colliding edit. This is a distinct problem from the general concurrent-session detection session-close runs — that check only detects that *another* session exists, not that it's about to make a colliding edit to a specific file. Two sessions independently proposing the identical one-line permission addition, caught only because one happened to read the same-day session log first, is the motivating case.
