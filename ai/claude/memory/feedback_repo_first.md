---
name: feedback_repo_first
description: "When working in the claude-skills repo, artifacts go in the repo first and are symlinked/deployed to the local system — not written directly to ~/.claude/"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3e7fd3bd-859c-4c9b-bdc9-b601e9c81c64
---

When creating any file that belongs to the Claude Code setup (hooks, scripts, configs, etc.) while working in the claude-skills repo, always:

1. Write the file into the repo (e.g., `hooks/`, `config/`, etc.)
2. Symlink it from the expected system location (e.g., `~/.claude/hooks/`) back to the repo path

**Why:** Keeps everything version-controlled in one place. Direct writes to `~/.claude/` bypass git and are harder to track, review, and share.

**How to apply:** Any time a new hook, script, or config artifact is created during a claude-skills session, default to repo → symlink flow rather than writing directly to `~/.claude/`.
