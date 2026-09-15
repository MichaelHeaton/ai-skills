# Environment capability check

`scripts/env-capability-check.sh` answers "what does this environment actually have" so a skill can route to a working fallback instead of failing mid-step. It's a shared script, not a skill — nothing invokes it by name; other skills source it as a precondition check.

## Why a script, not a skill

Several skills already ran ad hoc versions of this inline before this script existed — `session-close` alone had separate one-off checks for `gh` presence, `~/.config/ai-skills/local.json` presence, and the memex vault. A user never asks for "env-capability-check" as a workflow in its own right; it only ever runs as a means to another skill's end. That shape is a shared script consulted by many skills, not a standalone skill with its own trigger phrases — see `principles/core.md`'s "Decision authority" section.

## Usage

```bash
bash scripts/env-capability-check.sh [skill-name ...]
```

Prints one line per check, always — including the negative case — so a caller can `grep` for the line it needs rather than parsing conditionally:

```
GH_CLI:present:authenticated   # or present:unauthenticated, or absent
GLAB_CLI:present               # or absent
LOCAL_CONFIG:present:<path>    # or absent
MEMEX_VAULT:present:<path>     # or absent
DEPLOYED:<skill-name>:yes      # one line per name passed as an argument
```

Read-only and advisory — it never modifies anything and always exits 0. Consult the output; it is not a gate.

## What it doesn't cover

Skill-deployment staleness in a **cloud/web session** (a skill merged to `main` but never redeployed into the running container) is a structurally different problem from a missing local tool — see [ai-skills#128](https://github.com/MichaelHeaton/ai-skills/issues/128), which replaces manual push-based cloud deployment with a native plugin marketplace. Once that ships, "is this skill actually here" stops being something to detect after the fact. `DEPLOYED:<name>` above only checks the **local** symlinked install (`~/.claude/skills/<name>/SKILL.md`), which per `principles/deployment.md` can't go stale on its own — it's useful for confirming a skill exists at all, not for diagnosing cloud drift.
