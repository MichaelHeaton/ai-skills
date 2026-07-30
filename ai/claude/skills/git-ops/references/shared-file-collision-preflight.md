---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# Pre-flight: colliding open PR on a shared file

Before committing a change to a file that's shared and frequently touched across sessions (`.claude/settings.json` is the recurring offender in this repo), check for an existing open PR against it first:

```bash
gh pr list --search "<file-path-or-filename>" --state open --repo <owner>/<repo>
```

If an open PR already touches that file, fold the new content into it or wait for it to merge, rather than proposing an independent, likely-colliding edit. This is a distinct problem from the general concurrent-session detection session-close runs — that check only detects that *another* session exists, not that it's about to make a colliding edit to a specific file. Two sessions independently proposing the identical one-line permission addition, caught only because one happened to read the same-day session log first, is the motivating case.
