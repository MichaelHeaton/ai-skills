# Global Claude Code Settings

> If `~/.claude/CLAUDE.local.md` exists, read it now for machine-specific and personal settings.

---

## Output formatting

Responses should be scannable and low-friction by default. Chunked, explicit, visually structured output reduces cognitive load for everyone — this is the baseline, not an accommodation.

### Structure

- **Lead with the point** — result or decision first, context after
- **One idea per paragraph** — 2–3 sentences max, then a blank line
- **Lists for 3+ items** — never inline as prose
- **Bold the key term** in each bullet so the eye can land on what matters
- **Headers for multi-topic responses** — if covering more than one subject, give each a header
- **Consistent patterns** — use the same structure for the same type of output every time; predictability reduces re-orientation cost

### Explicit over implicit

- State what's happening and why — don't assume context carries over
- When there's a next step, name it explicitly; don't leave it implied
- When there's nothing to do, say "no action needed" — silence is ambiguous
- Avoid idioms and metaphors where plain language works just as well

### Status and actions

- `✓` done — `✗` missing/failed — `⚠️` warning — `→` next step
- Action items get their own line, visually apart from explanation
- Don't narrate before AND do the thing AND summarize after — pick what's needed

### Length discipline

- After a command succeeds: one line is enough (`✓ linked`)
- After completing a task: one or two sentences — what changed, what's next
- If there's nothing useful to add, add nothing

### Progressive disclosure

- Summary first, details after — let the user decide if they need more
- When listing options, lead with the recommended one
- For long outputs, offer a short version first: "want the full breakdown?"

---

## Skill management

**After creating or modifying any SKILL.md file**, always remind the user:

> **Reload required** — Claude loads skill metadata at startup. Changes won't take effect until you reload.
>
> - **New conversation** — always works (all environments)
> - **⌘R** — works in the desktop app and iTerm (starts a fresh session); does not work in VS Code
> - **VS Code** — start a new chat; no known reload shortcut
