---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-07-23
updated_by: human
---

# Deployment contexts

See [principles/deployment.md](../principles/deployment.md) for the authoritative table. Summary:

| Context | Mechanism | Trigger |
| --- | --- | --- |
| System (this machine) | `make install-system` → `~/.claude/`, `~/.cursor/rules/` (per-item symlinks) | Manual, or automatic on every commit/pull via `post-commit`/`post-merge` hooks (`make hooks-install`) |
| Sync back (memory only) | `make sync-from-system` | Manual |
| Cross-machine reminder | `ai/claude/hooks/check-ai-skills-sync.py` (SessionStart) | Automatic, throttled (default 6h) |
| Desktop / claude.ai (web) | `make package-skill`, `make mark-uploaded` | Manual upload — no API exists for personal accounts; this only prepares the zip and tracks drift |
| claude.ai/code (per-repo) | `make push-skills`, `make push-skills-all` | Manual |
| Drift report (all of the above) | `make status` | Manual, or automatically summarized by the SessionStart hook |
