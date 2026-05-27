---
name: feedback_repo_first
description: "When working in ai-skills, artifacts go in the repo first and are copied/deployed to ~/.claude/ — not written directly there"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3e7fd3bd-859c-4c9b-bdc9-b601e9c81c64
---

When creating any file that belongs to the Claude Code setup (hooks, scripts, configs, skills, etc.) while working in **ai-skills**, always:

1. Write the file into this repo under **`ai/claude/`** (e.g. `ai/claude/hooks/`, `ai/claude/skills/<name>/`, `ai/claude/memory/`)
2. Deploy with **`make install-system`** in ai-skills — **copy-only**, never symlinks

**Why:** Keeps everything version-controlled in one place. Direct writes to `~/.claude/` bypass git and are harder to track, review, and share. Symlinks break across machines and violate [principles/deployment.md](../../../principles/deployment.md).

**How to apply:** Any time a new hook, script, skill, or config artifact is created, default to **ai-skills → copy deploy** rather than writing directly to `~/.claude/` or linking with symlinks. If you find a symlink under `ai/`, replace it with a real file (see `make import-legacy` step 5 for skill conventions).

If you edited under `~/.claude/` first, run `make sync-from-system` before the next `make install-system`.
