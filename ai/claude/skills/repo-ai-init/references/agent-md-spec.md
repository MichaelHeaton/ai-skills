---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# AGENT.md Specification

This defines the standard structure for `AGENT.md` files. The goal is a document that:

- Any AI agent from any provider can read and act on
- Explains the *why* behind decisions, not just the *what*
- Stays focused on what is non-obvious from the code itself
- Is maintained alongside the codebase, not written once and forgotten

---

## File location

`AGENT.md` lives in the repository root, alongside `README.md`.

## Relationship to other AI context files

```
AGENT.md                    ← source of truth, provider-agnostic
CLAUDE.md                   ← Claude Code overlay, references AGENT.md
.cursorrules                ← Cursor overlay, references AGENT.md
.github/copilot-instructions.md  ← Copilot overlay, references AGENT.md
```

Provider-specific files should be thin. They add tool configuration and explain tool-specific behaviors. They do not duplicate AGENT.md content.

---

## Standard structure

```markdown
# AGENT.md — [Project Name]

> AI agent context document. Read this before working in this repository.
> Provider-specific configuration: see [CLAUDE.md](CLAUDE.md) (Claude Code), etc.

## What this is

[1–3 sentences: what the project does, why it exists, who uses it.]

## Architecture

[How the system is structured. Key components and how they relate.
Include a diagram if the repo has one; otherwise describe the main
modules/services/layers and their responsibilities.

Focus on decisions that aren't obvious from the file structure.]

## Getting started

[Commands to build, test, and run the project. Be specific.]

\`\`\`bash
# Install
<command>

# Build
<command>

# Test
<command>

# Run / serve
<command>
\`\`\`

## Conventions

[The unwritten rules that experienced contributors follow. These are
the things that would cause a PR to be rejected even though the code
"works." Explain the why — an AI that understands the reasoning can
apply it to new situations.]

### Naming
[File, function, variable, branch naming rules]

### Structure
[Where things go. When to create a new file vs extend an existing one.]

### Patterns
[Preferred patterns and anti-patterns specific to this codebase.]

## Key files

[The 5–10 files an AI should read to understand the system. Not every
file — just the ones that carry the most architectural weight.]

| File | What it does |
| --- | --- |
| `path/to/file` | [Why this file matters] |

## Common tasks

[Step-by-step for the most frequent AI-assisted tasks in this repo.
If a task has non-obvious steps or common failure modes, document them.]

### [Task name]
[Steps]

## Security

[Sensitive areas. What an AI should never touch without explicit
instruction. How credentials are handled. Where secrets live and
how they're accessed.]

## Gotchas

[Things that would surprise a capable AI seeing this codebase for the
first time. Accumulated from real incidents where AI got it wrong.]

- **[Thing]**: [Why it's surprising and what to do instead]

## What's not documented here

[Honest acknowledgment of gaps. Links to external docs, wikis, or
Confluence pages that cover things this file doesn't.]
```

---

## Writing guidelines

**Length**: There's no length limit, but prefer depth over breadth. A detailed Gotchas section with real examples is more valuable than exhaustive coverage of obvious things.

**Tone**: Write as if briefing a highly capable colleague who has never seen this repo. They're smart, they can read code — but they don't know the organizational context, the history of decisions, or the implicit conventions.

**Don't**: List every file and folder. Describe what every function does. Restate things that are obvious from README.md. Write rules without explaining why they exist.

**Do**: Document the surprising things. Explain rejected alternatives. Call out the files that carry the most weight. Flag the things that have tripped up smart contributors before.

**Update trigger**: Update AGENT.md whenever an AI (or a new contributor) does something wrong that the code didn't prevent. That's a gap. A one-sentence addition to Gotchas closes it permanently.
