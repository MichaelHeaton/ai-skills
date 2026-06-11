# Skill Distribution Strategy

> Design decisions for cross-repo skill access (web/mobile Claude Code sessions).
> Implementation: PR #45 (`feat: cross-repo skill bundle system`).

## Problem

Skills in `~/.claude/skills/` are only available in local CLI sessions. Web (`claude.ai/code`) and mobile sessions run in remote containers and only see `.claude/skills/` committed inside the repo being worked on. Manual per-repo sync is not sustainable as the skill library grows.

## Solution: Bundle system

A `skill-sets/` directory in `ai-skills` defines named subsets of skills appropriate for different repo types. `scripts/push-skills.sh` copies the right bundle into any target repo's `.claude/skills/` and commits.

```bash
make push-skills PROJECT=~/code/my-sre-repo BUNDLE=sre
```

## Design decisions

### Bundle structure: standalone, not additive

Bundles are **standalone** — each one is a complete, self-contained set for its domain. They do not compose `universal + domain-extras`.

**Why:** Additive bundles require every bundle definition to know about `universal`, and adding a skill to `universal` silently expands every bundle. Standalone bundles are explicit about what's in them — you can read one file and know exactly what skills a repo gets. The duplication is small (universal skills appear in multiple bundle files) and worth the clarity.

**Exception**: The `universal` bundle by convention contains only the skills that are genuinely cross-domain. Other bundles may include everything in `universal` by listing those skills explicitly.

### git push: manual (no `--push` flag)

The script copies skills and commits but does **not** push. The push is left to the caller intentionally.

**Why:** Pushing side-effects in a helper script are hard to audit, can surprise users in CI contexts, and interact badly with branch protection rules. Committing is local and always reversible; pushing is public and may trigger hooks or CI.

A `--push` flag could be added in the future if the workflow proves burdensome, but the safe default is no auto-push.

### Bulk sync: `push-skills-all` with a manifest

A `make push-skills-all` target should be added alongside a `skill-sets/repo-manifest.txt` file listing known repos and their bundles:

```
# repo-manifest.txt — known repos for push-skills-all
# format: <path> <bundle>
~/Projects/personal/ai-skills  universal
~/code/sre-repo                 sre
~/code/docs-repo                engineering
```

```bash
make push-skills-all   # syncs all repos in repo-manifest.txt
```

This is the right answer for keeping multiple repos in sync after a skill update. **Not yet implemented in PR #45 — tracked as a follow-on.**

### Mobile Claude app (non-Code)

Regular Claude chat and the mobile Claude app have no skill system. The equivalent is a **Claude Project** with the relevant skills pasted into the system prompt.

For skills that are used heavily in non-Code contexts (e.g. `comms-write`, `weekly-report`), a separate Projects-based workflow should be maintained. This is out of scope for the bundle system — they solve different problems.

### Why not submodules or subtrees?

Submodules and subtrees make the _whole_ repo available at a path — there's no built-in mechanism to include only a subset of skills. Filtering with subtree is awkward and non-obvious.

Plain copy+commit via `rsync` is simpler, auditable in git history, and requires no git plumbing knowledge to maintain. The only downside is that updates aren't automatic — but `make push-skills-all` makes the manual step a single command.

## Status

- PR #45: draft — bundle files, `push-skills.sh`, Makefile targets. Ready to review and merge.
- `push-skills-all` + manifest: not in PR #45 — tracked as a follow-on once the base is merged.
- Projects-based workflow for mobile: out of scope for the bundle system.
