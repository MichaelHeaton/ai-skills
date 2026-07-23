---
version: 2.0.0
principles_version: 1.0.0
last_updated: 2026-07-23
updated_by: human
---

# Deployment principles

## Contexts

| Context | Mechanism | Status |
| --------- | ----------- | -------- |
| **System** | `make install-system` → `~/.claude/`, `~/.cursor/rules/` (per-item symlinks) | **Present** |
| **Reconcile (automatic)** | `post-commit`/`post-merge` hook → `scripts/reconcile-symlinks.sh` | **Present** |
| **Sync back (memory only)** | `make sync-from-system` → repo | **Present** (dry-run default) |
| **Cross-machine reminder** | SessionStart hook `check-ai-skills-sync.py` | **Present** (throttled) |
| **Desktop / claude.ai** | `make package-skill`, `make mark-uploaded` | **Present** (manual upload; packaging + drift tracking only) |
| **claude.ai/code (bulk)** | `make push-skills-all` + `~/.config/ai-skills/push-targets.json` | **Present** |
| **Status** | `make status` | **Present** |
| **Repo** | `make install-repo` → project `.cursor/rules` | Planned |
| **Manifest** | `.deploy/repo-manifest.json` | Present — `make manifest-update` |
| **Web UI** | Pasted instructions; no filesystem `local.json` | To be documented |

## Copy vs symlink (reversed in v2.0.0)

**What changed:** Prior to v2.0.0, `install-system` copied `ai/claude/` and `ai/cursor/rules/` into `~/.claude/` / `~/.cursor/rules/`. As of v2.0.0, it creates **per-item symlinks** instead: each skill directory, hook file, agent file, cursor rule, and `CLAUDE.md` is its own symlink into this repo. The containing directories (`~/.claude/skills/`, `~/.claude/hooks/`, etc.) stay real — only the entries inside them are links.

**Why the reversal:** The v1.0.2 "no symlinks" decision was a reaction to a *whole-directory* symlink (the legacy `claude-skills` repo owned all of `~/.claude/skills` via one symlink, so no other repo could contribute skills there). That problem is real, but per-item symlinking doesn't share it — multiple repos can each own their own named entries in a shared directory. Adobe's internal `ces-internal-skills` repo already runs this pattern in production (`ln -s "$(pwd)/ces-internal-skills/Vault/vault-cmr" ~/.claude/skills/vault-cmr`) specifically so `git pull` keeps a skill live with no redeploy step. This repo now follows the same model for its own content.

**What symlinking buys us:** editing in the repo (or `git pull`) is immediately live under `~/.claude/` — no `make install-system` step is needed to pick up a content change to something already linked. `install-system`/`reconcile-symlinks` now only have work to do when an item is **added** or **retired**.

**What still copies, unaffected by this reversal:**

- `config/local.template.json` → `~/.config/ai-skills/local.json` — private, per-machine secrets, create-if-missing only. Never a symlink.
- `ai/claude/memory/` → `~/.claude/projects/<encoded-repo-path>/memory` — Claude Code's own session memory for sessions run *inside this repo*. This path is already unique per-repo, so it has no multi-repo problem to solve, and the manual review gate in `sync-from-system --apply` is a feature — it stops half-formed live scratch content from silently becoming tracked repo content.
- `scripts/push-skills.sh` (bundle distribution *into* other repos) — still copy+commit. A symlink there would point at an absolute path valid only on this machine, breaking the moment the target repo is cloned elsewhere (CI, another laptop, a cloud coding session).

## Safety invariants (new in v2.0.0)

1. **Never touch what this repo doesn't own.** A symlink is only created where nothing exists, or replaced where it already resolves inside this repo. A real file/dir at a destination is left alone unless byte-identical to the repo copy (presumed our own pre-migration content) or `--force` is passed. A symlink pointing outside this repo is *never* touched — `--force` does not override this.
2. **Retiring an item only removes a symlink this repo put there.** A real directory of the same name as a retired skill cannot be deleted by this repo's tooling.
3. **Migration is inline, not a one-off script.** `make install-system` detects a pre-v2.0.0 copy install by content comparison: identical → auto-converts to a symlink; different → aborts before touching anything and asks for `--force` or `make sync-from-system` first — now covering hooks/agents/CLAUDE.md/cursor-rules too (previously only skills were checked), since replacing real content with a symlink is less reversible than a copy overwrite.
4. **The automatic post-commit/post-merge hook never aborts.** `scripts/reconcile-symlinks.sh` only creates brand-new links or removes self-owned links, so it needs no staleness gate and is safe to run unattended with no `|| true` wrapper.

## install-system

Deploys from `ai/claude/` and `ai/cursor/rules/` as **symlinks**:

- `skills/<name>` → `~/.claude/skills/<name>`
- `hooks/*.py` → `~/.claude/hooks/*.py`
- `agents/*.md` → `~/.claude/agents/*.md`
- `CLAUDE.md` → `~/.claude/CLAUDE.md`
- `ai/cursor/rules/*.mdc` → `~/.cursor/rules/*.mdc` (does not remove other rules you add locally)
- `memory/` → `~/.claude/projects/<encoded-repo-path>/memory` (copy — see above)
- `log-clip` → `~/.local/bin/clog` (symlink)
- `config/local.template.json` → `~/.config/ai-skills/local.json` (create-if-missing copy only)

Removes retired skills/cursor rules (`RETIRED_SKILLS`/`RETIRED_CURSOR_RULES` in `scripts/lib/deploy-paths.sh`) — only if the destination is still a symlink resolving into this repo.

**Does not overwrite:** `settings.json`, `CLAUDE.local.md`, filled `local.json`, any real file, or any symlink belonging to another tool/repo.

**Safety:** Aborts before making changes if a destination holds real content differing from the repo. Use `make sync-from-system` to review, or `make install-system --force` to overwrite.

## reconcile-symlinks (automatic)

Runs on `post-commit`/`post-merge` (registered by `make hooks-install`). Creates symlinks for new items, removes symlinks for retired items, never touches an already-correct link, never touches ambiguous real/foreign content, never aborts. Does not touch `memory/` or `local.json`.

## Repo lint hooks

Markdown and YAML lint run via **pre-commit** (`.pre-commit-config.yaml`). On playbook-managed Macs, **workstation-devops** runs `make hooks-install` after `make install-system` on every clone and `make apply`. `hooks-install` also registers the `post-commit`/`post-merge` reconcile hook. Manual: `brew install pre-commit && make hooks-install`. Check anytime: `make lint`. CI: `.github/workflows/lint.yml`.

## sync-from-system (narrowed in v2.0.0)

Symlinked content can't diverge from the repo — nothing left to "sync back" for skills/hooks/agents/`CLAUDE.md`/cursor-rules unless something's gone wrong.

| Section | Behavior |
| --------- | ---------- |
| **Memory** | Unchanged: whitelist copy, dry-run default, `--apply`, then review + `make manifest-update` + PR. |
| **Symlink integrity** | Diagnostic only: flags any known item whose destination isn't a symlink into this repo (not migrated yet, or an editor replaced the symlink with a real file on save). Never auto-ingests — diff it yourself, then `make install-system --force`. |

Never syncs: `local.json`, `settings.json`, `CLAUDE.local.md`, secrets.

## One-time migration from a copy-based install

No dedicated script — `make install-system` migrates inline:

```
git pull
make install-system-dry-run
make install-system
```

If flagged as differing: `make sync-from-system` → review → `make install-system --force` if the stale copy isn't worth keeping. Foreign content (another tool's real directory, or an existing symlink of a different name) is left untouched throughout.

## One-time migration from symlink installs (legacy, pre-v1.0 claude-skills repo)

`make unlink-legacy` materializes `~/.claude/skills` as copies and can migrate config to `~/.config/ai-skills/`. This was Phase 0 of leaving the old *whole-directory*-symlinked `claude-skills` repo, and is unrelated to the v2.0.0 per-item symlink model above.
