---
version: 1.3.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: repo-ai-init
description: Analyze an existing git repository and apply AI best practices — creating AGENTS.md (provider-agnostic context, or AGENT.md if that's the repo's existing convention), CLAUDE.md (Claude-specific overlay), and identifying documentation gaps. Makes old repos understandable to any AI agent, not just Claude. Use when pointed at a repo that has no AI context files, when AI tools feel "blind" to a codebase, or when onboarding a repo to Claude Code. Triggers on: "set up AI support for this repo", "add AI context to this project", "make this repo AI-ready", "create an AGENTS.md", "this repo has no CLAUDE.md", "AI doesn't understand this codebase".
compatibility: Requires git.
---

# Repo AI Init

Transform any git repository — including legacy codebases built before AI tooling existed — into one that any AI agent can understand and work with confidently.

The core output is two files:

- **`AGENTS.md`** — provider-agnostic. Any AI from any company reads this and gets full context on the repo: what it is, how it works, its conventions, its gotchas. This is the single source of truth. Write to `AGENTS.md` by default; if the repo already has a root `AGENT.md` (singular) in place, detect that existing convention and keep writing to it instead of forcing a rename.
- **`CLAUDE.md`** — Claude-specific overlay. References the resolved AGENT.md/AGENTS.md file for general context. Adds Claude Code configuration (hooks, allowed tools) and explains *why* those choices exist — so another AI reading it can understand the reasoning rather than just the rules.

Read `references/agent-md-spec.md` before writing any files — it defines the standard AGENTS.md structure.

---

## Phase 1: Discovery

Before asking the user anything, run the discovery script from the target repo's directory:

```bash
bash <path-to-skill>/scripts/discover.sh [repo-path]
```

The script produces a structured report covering: file structure, tech stack, existing AI context files, build/test commands, README, and git history patterns. Read it fully before forming any conclusions.

After reading the report, also skim 2–3 key source files to understand the main patterns — the script shows you what exists, but reading the actual code builds the mental model. For docs repos, read the schema or template files instead.

**Tech-stack blind-spot check (optional, cheap).** The TECH STACK section above checks a fixed list of manifest filenames — a repo using a build system outside that list (Deno, Composer, sbt, CMake) won't be flagged even though a manifest exists. Run `bash <path-to-skill>/scripts/check-tech-stack-coverage.sh <repo-path>` to independently scan for other common manifest patterns; a `MISSED:tech-stack:<file>` line means the discovery report likely missed part of the tech stack. Same coverage-audit pattern `agent-md-sync` uses for its own component detector — see that skill's `references/coverage-audit-pattern.md` for the general form.

Build a working theory of:

- What this project does and why it exists
- Primary language and framework
- How it's built, tested, deployed
- Likely conventions (naming, file structure, module boundaries)
- Any obvious security-sensitive areas (credential handling, auth, infra config)

---

## Phase 2: Interview

Present your understanding to the user and fill the gaps that code can't answer. Keep it focused — don't ask what you can infer.

Key things that are never in the code:

- Architectural decisions that were considered and rejected (the *why* behind the current design)
- Organizational context (who owns this, who uses it, what breaks if it goes down)
- Unwritten conventions that experienced contributors follow instinctively
- Things that have tripped up new contributors before
- Security-sensitive areas that need extra care
- Anything an AI might "helpfully" change that would actually break things

Ask 5–8 targeted questions. Wait for answers before writing anything.

---

## Phase 3: Write AGENTS.md

Use the structure defined in `references/agent-md-spec.md`.

Key principles:

- Write for *any* AI agent, not just Claude. Avoid Claude-specific terminology.
- Explain the *why* behind conventions and architectural decisions — don't just list rules. An AI that understands why a rule exists can apply it to new situations; one that only knows the rule will break it at the first novel case.
- Focus on the non-obvious. Don't describe things derivable from the code itself. Document what would surprise a capable AI that just read all the files.
- DRY: if something is well-documented in a README or spec, link to it rather than restating it.
- Be specific. "Use camelCase for functions" is useful. "Write clean code" is not.

Show the draft to the user for review before saving. Apply feedback, then write to `AGENTS.md` in the repo root — unless discovery found an existing root `AGENT.md` (singular), in which case respect that convention and write there instead.

---

## Phase 4: Write CLAUDE.md

CLAUDE.md has a specific relationship with AGENTS.md: it's a thin overlay, not a standalone document.

Structure:

```markdown
# CLAUDE.md

> Claude Code configuration for [Project Name].
> For full project context, read AGENTS.md first.

## Claude Code settings
[Hooks, allowed tools, env vars — only what's actually configured]

## Why Claude does things this way
[Explain the reasoning behind each Claude-specific configuration,
so that other AI agents reading this file can understand the intent
and apply equivalent patterns in their own tooling.]
```

The "why Claude does things this way" section matters more than it might seem. When another AI (or a future model) reads this file, it should be able to understand:

- Why a hook runs before commits (e.g., "to prevent secrets in skill files")
- Why certain tools are pre-approved (e.g., "read-only git commands that are safe to run without prompting")
- Why the model is set to Sonnet instead of Haiku (e.g., "this repo requires multi-file reasoning")

If there's no existing `CLAUDE.md` and no Claude Code configuration to document, create a minimal one that just references the resolved AGENTS.md/AGENT.md file and leaves the settings sections empty with comments.

Show the draft to the user before saving.

---

## Phase 5: Identify Gaps and Next Steps

After writing both files, do a final pass and report:

**Undocumented areas**: What parts of the codebase are still opaque? What would an AI get wrong on first contact?

**Missing conventions**: What patterns exist in the code that aren't captured in AGENTS.md yet?

**Suggested follow-ups**: What should be added over time as the repo evolves? (e.g., "Add a section on deployment once the CI pipeline is documented")

**Other AI tools**: If the user works with Cursor, Copilot, or Aider, offer to generate their config files too — each should reference the resolved AGENTS.md/AGENT.md file as the source of truth and add only tool-specific configuration.

---

## Phase 6: Offer component-level AGENTS.md generation

After writing the root AGENTS.md (or AGENT.md, if that's the repo's existing convention) and CLAUDE.md, offer to continue with the `agent-md-sync` skill in scan mode:

> "Root AGENTS.md written. Would you like to also generate component-level AGENTS.md files for the roles/modules in this repo? I can scan for Ansible roles, Terraform modules, Helm charts, and other components."

This is optional — offer it, don't force it. If the repo has many components, the user may prefer to generate them incrementally as they work in each one.

---

## Maintenance note

Tell the user: AGENTS.md (or AGENT.md, if that's the repo's existing convention) is a living document. The best time to update it is right after something surprised an AI — that surprise is evidence of a gap. A one-sentence addition to the Gotchas section prevents the same confusion from happening again.
