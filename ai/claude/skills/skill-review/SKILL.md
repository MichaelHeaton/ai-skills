---

name: skill-review
description: Review and improve skills — either a single skill or all skills used in the current session. Single-skill mode: audits a SKILL.md against conventions, incorporates session learnings, and tunes triggering. Session-audit mode: reflects on the current conversation to find skill friction, missed triggers, and workflow gaps worth turning into new skills — meant to be called at the end of every session to make skills a little better each time. Also invoked programmatically by a parent session passing pre-collected session context (sub-agent mode: SA1 done by parent, SA2–SA4 run in sub-agent with fresh skill files). Triggers on: "review this skill", "improve skill X", "this skill isn't working well", "update skill based on what we learned", "skill feels off", "tune skill description", "review skills from this session", "what skills need updating", "session skill review", "audit skills", or when session-close reaches its skill hygiene step.
compatibility: Requires git. Skills must be installed via `make install` so ~/.claude/skills/ and ~/.claude/references/ symlinks exist.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# Skill Review

This skill has two modes. Read the user's request to determine which to run:

- **Single-skill mode** — user names a specific skill to review (`"review issue-create"`, `"this skill feels off"`)
- **Session-audit mode** — user wants a sweep of all skills used in this session (`"audit skills"`, `"session skill review"`, or called from session-close Step 6)

If unclear, ask: "Do you want to review a specific skill, or do a session-wide sweep?"

---

## Session-audit mode

Use this when called at the end of a session or when the user wants a sweep rather than a targeted review.

### SA1. Identify skills used this session

**If this invocation includes a pre-summarized context block** (skills list + friction notes passed by a parent session): use that as SA1 output and skip to SA2. See [Sub-agent invocation pattern](#sub-agent-invocation-pattern) below.

**If no context block is provided and no conversation history exists**: halt and return: "No session context available — re-invoke with a context block or run from the parent session."

Otherwise: reflect on the current conversation. Look for every Skill tool invocation or place a skill was named and executed. Build a list.

### SA2. Assess each skill that fired

For each skill that ran, evaluate:
- **Did it trigger correctly?** Did I reach for it at the right moment, or did the user have to ask explicitly?
- **Did it route correctly?** (Wrong repo, wrong ticket system, wrong output format?)
- **Was there a correction loop?** Did the user have to redirect me mid-execution?
- **Was context I should have inferred missing?** (e.g. I searched for a repo name that was a voice transcription artifact)

Flag any with friction. If a skill ran cleanly with no issues, note it but don't force a change.

### SA3. Identify ungapped workflows

Look for any multi-step work that ran without a skill — no skill fired, but the pattern is repeatable. Examples:

- Decoding `.eml` → extracting content → writing a vault note → deleting source
- Capturing a meeting: attendees, decisions, open questions, action items → vault note + optional ticket
- Summarizing a Slack thread into a vault note
- Any workflow where the user said "I do this regularly" or that visibly happened more than once

### SA4. Output the skill delta

Produce two lists:

**Existing skills to improve** — name the skill, describe the specific fix (quote the friction if possible). Offer to run single-skill mode on it now or create a ticket in claude-skills.

**New skill ideas** — proposed name + one sentence on what it does. Offer to invoke `skill-create` now or create a ticket in claude-skills.

If there's nothing to improve: say "no skill changes identified this session" — don't manufacture findings.

**If running as a sub-agent** (a context block was passed as input rather than a live conversation): return the findings table only — do not offer to act. SA5 is the parent session's responsibility.

### SA5. Create tickets, then act

**Default: always create a ticket first**, even if you're about to work the finding immediately. The ticket preserves context and history regardless of whether it gets closed in the same session.

Use `issue-create` Path B targeting `${GITHUB_PERSONAL_USER}/claude-skills`.

**Security check before creating any ticket** — claude-skills is a **public GitHub repo**. Before writing ticket content, strip or generalize:
- Adobe-internal hostnames, URLs, or system names
- Internal ticket keys used as examples (CESSS-XXXXX etc.)
- Security findings, vulnerability details, or exploit patterns
- Credentials, tokens, or secrets of any kind
- Any detail that would only make sense to someone inside Adobe or UV Cyber

Describe the skill improvement in generic terms. "The skill failed to detect the repo name from voice input" is fine. "The skill couldn't find the internal secrets management repo at git.corp.example.com" is not.

Once the ticket exists:
- **Work it now** → continue into single-skill mode or `skill-create`, then close/transition the ticket
- **Defer it** → leave the ticket open, move on

If the user explicitly declines a ticket for a finding: acknowledge and move on — don't force it.

---

## Sub-agent invocation pattern

Run SA2–SA4 inside a sub-agent when you want fresh skill file reads mid-session (sub-agents reload all SKILL.md files from disk at startup) or when the accumulated session context would distort the audit.

**Division of labor:**
- **Parent session** — does SA1 (has the conversation history), then spawns a sub-agent
- **Sub-agent** — receives the SA1 output as structured input, runs SA2–SA4, returns findings table
- **Parent session** — handles SA5 (ticket creation, security scrub)

**What the parent must pass to the sub-agent:**

```
## Session context (from parent)

Session focus: [one sentence]
Skills active this session:
- <skill-name> (global: claude-skills)
- <skill-name> (project: <repo-name>)
Friction observed: [bullet list — what went wrong or felt off]

## Your task

Run skill-review session-audit steps SA2–SA4.
SA1 is complete — use the context above as input.
Read ~/.claude/skills/{name}/SKILL.md fresh for each skill listed.
Return ONLY the findings table, new skill ideas table, and a one-paragraph summary.
Do NOT run SA5. Do NOT create tickets.
```

**Output format the sub-agent should return:**

```
### Findings Table
| Skill | Finding | Type | Proposed Change | Priority |
| skill-X | [text] | friction|gap|clean | [change or "none"] | high|medium|low |

### New Skill Ideas
| Proposed Name | One-line Description |

### Summary
[1–2 sentences]
```

**Security note**: SA5's security scrub (strip Adobe-internal details before public tickets) applies to the **parent session** when it acts on the sub-agent's findings — not to the sub-agent itself. The sub-agent returns findings; the parent creates tickets and must run the scrub.

---

## Single-skill mode

Your job is to help the user audit and improve an existing skill. Unlike skill-create, you're starting from something that exists — the goal is to make it better, not rebuild it from scratch.

The most common reasons to review a skill:
- It didn't trigger when it should have (or triggered when it shouldn't)
- The output felt off — too rigid, missed the point, did unnecessary work
- A session just produced a great result and that approach should be captured back into the skill
- Claude has new capabilities that the skill doesn't take advantage of
- The skill was written quickly and deserves a proper pass

---

## 1. Identify the Skill

If the user named a skill, read it from `~/.claude/skills/{name}/SKILL.md`.

If it's not clear which skill, list the available skills:
```bash
ls ~/.claude/skills/
```

Ask the user to confirm before proceeding.

---

## 2. Understand What Prompted the Review

Before reading the skill with fresh eyes, ask the user what triggered this. The answer shapes what kind of changes to make:

- **Session learnings** — "We just did X and it worked really well / really badly." Extract the specific pattern and bake it into the skill.
- **Triggering problems** — "It didn't fire" or "it fired when it shouldn't." Focus on the description.
- **Output quality** — "It keeps doing Y when I want Z." Look at the body instructions.
- **Model update** — A new Claude version may handle things differently; instructions that were necessary might now be redundant, or new capabilities might simplify the skill.
- **Periodic tune-up** — General review with no specific complaint. Do a full pass.

Get enough context before reading the skill so you know what to look for.

---

## 3. Audit the Skill

Read the skill's SKILL.md and evaluate it across these dimensions. Read `references/conventions.md` for the full rules.

### Naming
- Does the `name` match the directory name?
- Does it follow the `{domain}-{verb}` or `{domain}-{noun}` pattern?
- Is the domain prefix correct for this skill's context?

### Description (trigger quality)
The description is the primary trigger mechanism. Ask:
- Does it clearly state what the skill does AND when to use it?
- Does it include natural-language phrases a user would actually type?
- Is it pushy enough? (Claude undertriggers — the description should lean toward more situations, not fewer)
- Are there near-miss situations it should explicitly call out?
- Is it under 1024 characters?

### Output formatting

Global ADHD-friendly formatting rules live in `~/.claude/CLAUDE.md` — they apply to every session automatically and don't need to be in the skill. Check whether the skill unnecessarily duplicates formatting instructions that are already covered globally. If it does, remove them.

If the skill produces complex structured output, it may reference `references/formatting.md` for output-specific patterns — but only if the global rules aren't sufficient.

### Body (instruction quality)
- Is the structure logical? Would a reader follow it without confusion?
- Are instructions in imperative form ("Do X")?
- Does it explain the *why* behind non-obvious steps?
- Is anything redundant or not pulling its weight?
- Is it under 500 lines? If not, what could move to `references/`?
- Are there rigid ALWAYS/NEVER rules that should be replaced with explained reasoning?
- Does every skill invocation/reference include a source label? (`_(personal — claude-skills repo)_`, `_(built-in — Claude Code)_`, or `_(repo — <name>)_`)

### Freshness
- Does the skill reference tools, APIs, or patterns that have changed?
- Does it account for current Claude capabilities? (e.g., a skill that manually scaffolds something Claude now handles natively is doing unnecessary work)
- If a session just produced a better approach, is that approach captured?

---

## 4. Propose Changes

Present your findings as a clear list — what's working, what isn't, and what you'd change. Be specific: quote the problematic text and show the proposed replacement.

Don't rewrite everything unless the skill genuinely needs it. Targeted edits to the description and a few body refinements are usually more valuable than a full rewrite that loses what was working.

Get the user to agree on the changes before applying them.

---

## 5. Apply and Verify

Once the user approves:

1. **Determine the skill's source** — global or project — then edit the repo source file, never `~/.claude/skills/` (the installed copy is a deployment artifact overwritten by the next install):
   - **Global skill** → `~/Projects/personal/claude-skills/skills/{name}/SKILL.md`
     ```bash
     ls ~/.claude/skills/{name}/   # confirms global
     ```
   - **Project skill** → `<project-repo>/.claude/skills/{name}/SKILL.md`
     ```bash
     find ~/Projects -maxdepth 4 -path "*/.claude/skills/{name}" -type d 2>/dev/null
     # use the repo path returned here
     ```
   If session-close passed a source annotation (`global: claude-skills` or `project: <repo>`), use that directly instead of running the lookup.
2. Read it back and confirm it looks right
3. **Global skills only** — verify the skill has a row in `README.md` and skim `AGENT.md` for stale references; update both if needed
4. Remind them to `git commit && git push` in the correct repo, then `make install` (global) or the project's equivalent deploy step

---

## 6. Description Optimization (if triggering was the issue)

If the main problem was the skill not triggering correctly, offer a description sharpening pass:

1. Draft 8–10 "should trigger" prompts (varied phrasings, edge cases, casual speech)
2. Draft 8–10 "should not trigger" prompts (near-misses — same keywords but different intent)
3. Review the set with the user; prune bad examples
4. Rewrite the description to handle the edge cases
5. Apply the updated description to the frontmatter

Focus on the near-misses — prompts that obviously trigger or obviously don't are useless test cases. The value is in the ambiguous middle.
