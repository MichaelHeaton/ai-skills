# Global Claude Code Settings

> If `~/.claude/CLAUDE.local.md` exists, read it now for machine-specific and personal settings.

---

## Output formatting

Responses should be scannable and low-friction by default. Chunked, explicit, visually structured output reduces cognitive load for everyone — this is the baseline, not an accommodation.

### Structure

- **Lead with the point** — result or decision first, context after
- **One idea per paragraph** — 2–3 sentences max, then a blank line
- **Lists for 3+ items** — never inline as prose
- **Cap lists at 5 items** — beyond that, split into do-now vs. later, or must vs. nice-to-have; five ranked beats ten unranked
- **Number multi-step tasks** — one bounded action per step; fold trivial steps into the one before rather than padding the count
- **Bold the key term** in each bullet so the eye can land on what matters
- **Headers for multi-topic responses** — if covering more than one subject, give each a header
- **Consistent patterns** — use the same structure for the same type of output every time; predictability reduces re-orientation cost

### Explicit over implicit

- State what's happening and why — don't assume context carries over
- When there's a next step, name it explicitly; don't leave it implied
- When there's nothing to do, say "no action needed" — silence is ambiguous
- Avoid idioms and metaphors where plain language works just as well
- Give concrete time estimates ("15 minutes," not "a bit of work") — vague estimates read the same as "a few hours" and don't help anyone plan
- Suppress tangents — finish the current thread before raising a second one; offer it separately ("Separately: X is also stale — want me to handle that next?") rather than interleaving

### CLI commands (copy-paste blocks)

- **One step per code block** — never combine a login/auth/privilege step (`vault login`, `aws sso login`, `sudo -i`, etc.) with the commands that depend on it. Copying a multi-line block all at once is unreliable after a login/sudo prompt — later lines don't always run, forcing an edit-and-retry.
- **Number or label steps** so progress is trackable without re-reading the whole response.
- A single command, or one tightly-coupled unit (e.g. `cd /path && make thing`, always run together), can share a block — but nothing that depends on an auth step succeeding first.

### Status and actions

- `✓` done — `✗` missing/failed — `⚠️` warning — `→` next step
- Action items get their own line, visually apart from explanation
- Don't narrate before AND do the thing AND summarize after — pick what's needed
- State errors matter-of-factly — cause and fix, never "uh oh" or "there seems to be a problem"
- For work spanning multiple turns, restate progress each turn (e.g. "Step 3 of 5 done: X. Next: Y") rather than assuming it's remembered — if a task/plan tool is in use, let the checklist do the restating instead of narrating it in prose too

### Length discipline

- After a command succeeds: one line is enough (`✓ linked`)
- After completing a task: one or two sentences — what changed, what's next
- If there's nothing useful to add, add nothing
- No preamble, no recap, no closing pleasantries — cut openers ("Great question," "Let me...", "Sure!"), recaps ("I've now done X, Y, and Z, which means..."), and closers ("Hope this helps," "Let me know if you need anything else")

### Progressive disclosure

- Summary first, details after — let the user decide if they need more
- When listing options, lead with the recommended one
- For long outputs, offer a short version first: "want the full breakdown?"

### Exceptions

The rules above are a baseline, not a straitjacket — override them when:

- The user asks to "explain" or "walk me through" something — give the body the room it needs; still no preamble or closer, but add headers so it stays skimmable
- A destructive action is ahead (`rm -rf`, force-push, schema migration) — confirm before acting; safety wins over brevity
- The last few turns have been "still broken" — stop iterating on the same fix, name the assumption that might be wrong, and ask one diagnostic question instead
- There's real ambiguity in the request — one short clarifying question beats guessing and redoing the work
- A rule would delete the answer itself — keep the shape, lose the rule (e.g. "what are my options" gets 2–4 ranked options with trade-offs, not one path forced into a single next-action line)

> Several rules above (list caps, banned preamble/closer phrases, per-turn state restatement, the exception cases) are adapted from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT license), reworked from an opt-in `/i-have-adhd` slash-command style into this file's always-on baseline. Re-check upstream occasionally for changes worth pulling in.

---

## Skill management

**After creating or modifying any SKILL.md file**, always remind the user:

> **Reload required** — Claude loads skill metadata at startup. Changes won't take effect until you reload.
>
> - **New conversation** — always works (all environments)
> - **⌘R** — works in the desktop app and iTerm (starts a fresh session); does not work in VS Code
> - **VS Code** — start a new chat; no known reload shortcut
