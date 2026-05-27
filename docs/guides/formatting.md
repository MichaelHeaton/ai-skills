# Output Formatting Guide

Global formatting rules live in `~/.claude/CLAUDE.md` and apply to every session automatically. Skills do not need to repeat them.

This file exists for skill authors — use it when writing a skill that produces complex structured output and you want to reinforce specific patterns beyond the global defaults.

---

## When to reference this file

Reference it in a skill's SKILL.md when the skill:
- Produces multi-section reports (repo discovery, audit results, etc.)
- Has a defined output template that should be consistently formatted
- Needs to override or extend the global defaults for a specific output type

Otherwise, rely on the global `~/.claude/CLAUDE.md` — don't repeat formatting rules in every skill.

---

## Patterns for common skill output types

### Status reports (repo-setup, account checks)
```
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
Don't pad — if two options exist, show two.

### Errors and blockers
State what failed in the first line.
Give the specific cause on the next line (not a paragraph).
Give the fix as a concrete command or action, not a suggestion.

### Long reference material
Use headers to break it into scannable sections.
Keep each section under 10 lines where possible.
If a section would run long, move the detail to a `references/` file and link to it.
