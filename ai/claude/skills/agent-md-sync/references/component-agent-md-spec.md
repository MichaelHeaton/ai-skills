---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-24
updated_by: human
---

# Component AGENT.md Specification

Component AGENT.md files live alongside their component — `roles/nginx/AGENT.md`, `modules/vpc/AGENT.md`. They give AI agents focused context for working in a specific component without reading the whole repo.

## Relationship to root AGENT.md

The root `AGENT.md` defines repo-wide conventions. Component AGENT.md files should:

- Link back to the root for anything already documented there
- Only document what is **specific** to this component
- Not repeat repo-wide conventions unless the component deviates from them

If the root AGENT.md covers naming conventions, don't restate them. If this component has a specific exception or extension to those conventions, document only that delta.

## Standard structure

```markdown
# AGENT.md — [Component Name]

> [One sentence: what this component does.]
> Repo context: see [root AGENT.md](../../AGENT.md).

## Purpose

[2–4 sentences: what problem this component solves, when it's used, what it manages or configures.]

## Inputs / Interface

[Variables, parameters, or interfaces this component accepts.
For Ansible roles: role variables — required vs. optional, default values, what breaks if missing.
For Terraform modules: input variables — required vs. optional, types, constraints.
For other component types: function signatures, config keys, API contracts.]

## Key files

| File | What it does |
| --- | --- |
| `tasks/main.yml` | Entry point — [what it orchestrates] |
| `defaults/main.yml` | Default variable values |

## Conventions

[Anything specific to this component that differs from or extends the repo-wide conventions.
Omit this section entirely if the component follows standard patterns without deviation.]

## Gotchas

[Things that have tripped up AI or contributors working in this component.
Add entries after real incidents — not preemptively.]

- **[Thing]**: [Why it's surprising and what to do instead]
```

---

## Length target

**30–80 lines.** If a component AGENT.md exceeds 80 lines, it is probably capturing things that belong in the root AGENT.md or in inline code comments. Keep it focused.

## Writing guidelines

**Only the non-obvious.** Don't describe what the code makes obvious from reading it. Document what would surprise a capable AI that just read all the files in the component directory.

**Inputs section matters most.** For infrastructure components especially, the variables/inputs section is what an AI needs most when generating or reviewing changes. Be precise: name, type, required/optional, default, and one sentence on what breaks if it's wrong.

**Gotchas are worth gold.** A real gotcha — the kind that caused an incident or a wrong AI suggestion — is worth five paragraphs of general description. Capture them as they happen, not all at once during initial setup.

**Omit empty sections.** If there are no gotchas yet, omit the Gotchas section entirely. Don't add placeholder text.

## Update trigger

Update a component AGENT.md whenever:

- An AI does something wrong in this component that the code didn't prevent
- A variable or interface changes in a way that would surprise an AI reading the old file
- A non-obvious convention is established or changes

The git-ops skill checks for this at PR time and flags components whose AGENT.md wasn't updated alongside their code.
