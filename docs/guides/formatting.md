---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-27
updated_by: claude
---

# Output formatting guide

Global formatting rules live in `~/.claude/CLAUDE.md` and apply to every session automatically. Skills do not need to repeat them.

This file exists for **skill authors** — use it when writing a skill that produces complex structured output and you want to reinforce specific patterns beyond the global defaults.

---

## When to reference this file

Reference it in a skill's `SKILL.md` when the skill:

- Produces multi-section reports (repo discovery, audit results, etc.)
- Has a defined output template that should be consistently formatted
- Needs to override or extend the global defaults for a specific output type

Otherwise, rely on the global `~/.claude/CLAUDE.md` — do not repeat formatting rules in every skill.

---

## Patterns for common skill output types

### Status reports (repo-setup, account checks)

```text
✓ thing — one-line note
✗ thing — what's missing and what to do
⚠️ thing — warning with impact
→ next step
```

### Multi-step results (skill output after running)

Lead with a one-line summary of the outcome.
Follow with a tight bulleted list of what changed.
End with one sentence on what's next (if anything).

### Options / recommendations

Present the recommended option first, labeled `(recommended)`.
List alternatives below with one-line tradeoffs.
Do not pad — if two options exist, show two.

### Errors and blockers

State what failed in the first line.
Give the specific cause on the next line (not a paragraph).
Give the fix as a concrete command or action, not a suggestion.

### Long reference material

Use headers to break it into scannable sections.
Keep each section under 10 lines where possible.
If a section would run long, move the detail to a `references/` file and link to it.

---

## Written docs (SKILL.md, references/, runbooks, comms templates)

The same baseline applies to persisted documents, not just chat output — and it resolves a tension that looks real but isn't: ADHD-friendly readers want short, scannable, bulleted docs; an AI reading the same doc for context wants enough detail to act correctly. Those aren't opposing forces once you separate two different things that "short vs. robust" conflates:

- **Structure** (headers, bold lead terms, bullets, explicit sections) — both audiences want *more* of this, not less. It's what makes a doc skimmable for a human and parseable for a model.
- **Length** (how much prose sits under that structure) — this is genuinely traded off, and the fix is progressive disclosure, not picking one audience.

**Pattern**: a short top layer (bulleted summary, headers, bold key terms) that a human can skim in seconds, with full detail pushed into linked sections or a `references/` file that an AI (or a human who wants more) can traverse into. This repo already does this at the top level — `CLAUDE.md` is a thin overlay pointing to `AGENTS.md` and `principles/` rather than one monolithic doc — apply the same shape one level down, inside individual skill docs and runbooks.

**Do not treat this structure as an AI-writing tell to strip out.** Bold section labels and bulleted lists (`**Progress**` / `- bullet`) in an intentionally scannable doc — a SKILL.md, a runbook, an internal comms template — are deliberate accessibility structure, not padding. A cleanup pass (e.g. `humanizer`) that flattens them into paragraphs on the theory that "prose would read better" is optimizing for encyclopedic article style, which is the wrong target for this content — see the scoping note in that skill.
