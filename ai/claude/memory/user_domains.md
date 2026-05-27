---
name: user-domains
description: Work contexts and VCS routing — skill naming in docs/guides/skill-conventions.md; employer/client labels in ~/.config/ai-skills/local.json
metadata:
  type: user
---

Skill naming rules live in [docs/guides/skill-conventions.md](../../../docs/guides/skill-conventions.md). This public repo does **not** ship an employer prefix table — use private `~/.config/ai-skills/local.json` for account labels, Jira keys, and routing.

When suggesting a new skill name, follow the public conventions doc (default: no org prefix unless the skill is useless outside one scope).

**Contexts** (you define in `local.json` → `accounts`, `routing`, `jira`): e.g. personal PKM (Memex), employer work, client contract. Never commit filled employer or client names here.

**VCS routing (typical):**
- GitHub: personal + work remotes (see `accounts.*.remote_match` in local.json)
- GitLab: client or personal GitLab (`client_contract` or similar account block)
- Cross-platform skills: `issue-`, `pr-`, `git-` — no platform suffix unless the skill is platform-only
