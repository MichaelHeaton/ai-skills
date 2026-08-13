---
version: 1.7.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
name: skill-review
description: Review and improve skills — either a single skill or all skills used in the current session. Single-skill mode: audits a SKILL.md against conventions, incorporates session learnings, and tunes triggering. Session-audit mode: reflects on the conversation for skill friction and workflow gaps worth turning into new skills; scans usage counters for zero/dormant-usage skills across ALL installed skills, not just this session's; and flags skills whose SKILL.md hasn't been touched in 90+ days — run at the end of every session, or proactively right after a SKILL.md is edited directly (not through `skill-create`, which already reviews). Also invoked programmatically by a parent session passing pre-collected context (sub-agent mode: SA1 by parent, SA2–SA4 in sub-agent). Triggers on: "review this skill", "improve skill X", "skill isn't working well", "tune skill description", "session skill review", "audit skills", "stale skills", or when session-close reaches its skill hygiene step.
compatibility: Requires git. Skills deployed via `make install-system` (per-item symlinks; see principles/deployment.md).
---

# Skill Review

This skill has two modes. Read the user's request to determine which to run:

- **Single-skill mode** — user names a specific skill to review (`"review issue-create"`, `"this skill feels off"`)
- **Session-audit mode** — user wants a sweep of all skills used in this session (`"audit skills"`, `"session skill review"`, or called from session-close Step 6)

If unclear, ask: "Do you want to review a specific skill, or do a session-wide sweep?"

**Proactive trigger — direct SKILL.md edits.** When a SKILL.md is edited directly from conversation mid-session (not through `skill-create`'s own guided flow, which already runs review as part of creation), offer single-skill mode on that skill before treating the edit as done — a review at the point of change catches small issues (trigger drift, convention gaps) that would otherwise only surface if someone remembers to ask later.

---

## Session-audit mode

Use this when called at the end of a session or when the user wants a sweep rather than a targeted review.

### SA0. Check for stale skills (lightweight, runs every time)

Run this regardless of whether a conversation-context block is available — it doesn't need session reflection, only two local reads, so it isn't blocked by the SA1 halt condition below.

1. `jq '.skillUsage' ~/.claude.json` — lifetime `usageCount` and `lastUsedAt` per skill (never windowed, never reset).
2. `ls -la ~/.claude/skills/` (and `<project>/.claude/skills/` if the project has one) — the symlink/directory date is a proxy for how long each skill has been installed.
3. Flag a skill as **stale** if either:
   - It has no entry in `skillUsage` at all (zero lifetime dispatches) **and** its symlink/directory is older than ~2 weeks, or
   - It has a `lastUsedAt` older than ~90 days.
4. Skip anything installed less than ~2 weeks ago — too new to judge, note it rather than flagging it.

This reuses `/doctor` check 1's signal (skill usage counters) but skips its multi-session transcript scan — these two file reads are cheap enough to run at every session-close. Carry the result into SA4 as a third list.

### SA1. Identify skills used this session

**If this invocation includes a pre-summarized context block** (skills list + friction notes passed by a parent session): use that as SA1 output and skip to SA2. See [Sub-agent invocation pattern](#sub-agent-invocation-pattern) below.

**If no context block is provided and no conversation history exists**: halt and return: "No session context available — re-invoke with a context block or run from the parent session."

Otherwise: reflect on the current conversation. Look for every Skill tool invocation or place a skill was named and executed. Build a list.

**Also check for skills that have silently aged out of review** — a skill that never fires in a given session never comes up for audit through this path alone, so a low-frequency skill (e.g. `security-review`, `comms-write`) can go untouched indefinitely. Run:

```bash
bash ~/.claude/skills/skill-review/scripts/check-stale-skills.sh
```

This flags any skill whose `SKILL.md` `last_updated` is 90+ days old (`STALE:<days>:<skill>:<last_updated>`). Add flagged skills to a separate "Stale — due for a look" list alongside the ones that fired this session; they get the same SA2 treatment but note the reason is staleness, not observed friction.

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

Produce three lists:

**Existing skills to improve** — name the skill, describe the specific fix (quote the friction if possible, or "stale — last touched N days ago" for a staleness-only flag). Offer to run single-skill mode on it now or create a ticket in ai-skills.

**New skill ideas** — proposed name + one sentence on what it does. Offer to invoke `skill-create` now or create a ticket in ai-skills.

**Stale skills** (from SA0) — name each, its lifetime `usageCount` and `lastUsedAt` (or "never"), and why it was flagged. Propose disabling via `skillOverrides: {"<name>": "off"}` in `.claude/settings.local.json` (project skill) or `~/.claude/settings.json` (global skill) — reversible by removing the entry. Get explicit confirmation before disabling anything; don't apply silently.

If there's nothing to improve: say "no skill changes identified this session" — don't manufacture findings.

**If running as a sub-agent** (a context block was passed as input rather than a live conversation): return the findings table only — do not offer to act. SA5 is the parent session's responsibility.

### SA5. Create tickets, then act

**Default: always create a ticket first**, even if you're about to work the finding immediately. The ticket preserves context and history regardless of whether it gets closed in the same session.

Use `issue-create` Path B targeting `${GITHUB_PERSONAL_USER}/ai-skills`.

**Security check before creating any ticket** — ai-skills is a **public GitHub repo**. Before writing ticket content, strip or generalize:

- Employer-internal hostnames, URLs, or system names
- Internal ticket keys used as examples (PROJ-12345 etc.)
- Security findings, vulnerability details, or exploit patterns
- Credentials, tokens, or secrets of any kind
- Any detail that would only make sense inside a specific employer or client org

Describe the skill improvement in generic terms. "The skill failed to detect the repo name from voice input" is fine. "The skill couldn't find the internal secrets management repo at git.corp.example.com" is not.

Once the ticket exists:

- **Work it now** → continue into single-skill mode or `skill-create`, then close/transition the ticket
- **Defer it** → leave the ticket open, move on

If the user explicitly declines a ticket for a finding: acknowledge and move on — don't force it.

---

## Sub-agent invocation pattern

See [references/sub-agent-pattern.md](references/sub-agent-pattern.md) for the full prompt template, output format, and security notes.

---

## Single-skill mode

Audit and improve an existing skill — the goal is to make it better, not rebuild it from scratch.

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
- **Upstream check** — The skill's frontmatter has `metadata.adapted_from` set; verify whether the original source has changed in ways worth pulling in.
- **Periodic tune-up** — General review with no specific complaint. Do a full pass.

Get enough context before reading the skill so you know what to look for.

---

## 3. Audit the Skill

Read the skill's SKILL.md. Full audit dimensions are in `references/conventions.md`. Key checks:

- **Naming**: `name` matches directory; follows `{domain}-{verb}` or `{domain}-{noun}` pattern
- **Description**: states what + when; includes natural-language trigger phrases; pushy enough (≤1024 chars)
- **Output formatting**: don't duplicate rules already in `~/.claude/CLAUDE.md`
- **Body**: imperative form; explains non-obvious *why*; no dead weight; ≤200 lines or moved to `references/`; skill invocations include source label (`_(global: ai-skills)_`, `_(project: <repo>)_`, `_(built-in)_`)
- **Attribution**: if `metadata.adapted_from` is set, check whether the upstream source has moved on since — worth a quick skim if it's been a while (see `references/conventions.md` § Attribution)
- **CLI/runbook steps**: login/auth commands (`vault login`, `sudo -i`, etc.) are in their own code block, never combined with dependent commands (see `references/conventions.md`)
- **Freshness**: no stale tool refs; not scaffolding what Claude handles natively
- **Capability test**: for every line that reads like scaffolding rather than domain knowledge, ask "would a strong model behave worse without this line?" — project-specific gotchas and personal/team conventions are exempt by definition, never cut on this basis. Full delete-category taxonomy, keep-exemptions, and the required verdict format: [references/capability-test-pruning.md](references/capability-test-pruning.md). Every flagged line gets an explicit `KEEP`/`PRUNE` verdict with a reason — not a general "looks fine" impression of the section it's in. Zero prunes is a valid outcome; don't manufacture cuts to show work.

---

## 4. Propose Changes

Present your findings as a clear list — what's working, what isn't, and what you'd change. Be specific: quote the problematic text and show the proposed replacement.

Don't rewrite everything unless the skill genuinely needs it. Targeted edits to the description and a few body refinements are usually more valuable than a full rewrite that loses what was working.

Get the user to agree on the changes before applying them.

---

## 5. Apply and Verify

Once the user approves:

1. **Determine the skill's source** — global or project — then edit the repo source file, never `~/.claude/skills/` (the installed copy is a deployment artifact overwritten by the next install):
   - **Global skill** → `~/Projects/personal/ai-skills/ai/claude/skills/{name}/SKILL.md`

     ```bash
     ls ~/.claude/skills/{name}/   # confirms global
     ```

   - **Project skill** → `<project-repo>/.claude/skills/{name}/SKILL.md`

     ```bash
     find ~/Projects -maxdepth 4 -path "*/.claude/skills/{name}" -type d 2>/dev/null
     # use the repo path returned here
     ```

   If session-close passed a source annotation (`global: ai-skills` or `project: <repo>`), use that directly instead of running the lookup.
2. Read it back and confirm it looks right
3. **Global skills only** — verify the skill has a row in `README.md` and skim `AGENT.md` for stale references; update both if needed
4. Remind them to `git commit && git push` in the correct repo, then `make install` (global) or the project's equivalent deploy step

---

## 6. Description Optimization (if triggering was the issue)

Draft 8–10 "should trigger" and 8–10 "should not trigger" prompts. Focus on near-misses — the ambiguous middle, not obvious cases. Review with the user, prune, then rewrite the description to handle the edge cases and apply to frontmatter.
