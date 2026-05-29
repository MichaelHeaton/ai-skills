---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: skill-create
description: Create a new Claude Code skill from scratch using a guided interview. Handles the full lifecycle — capturing intent, naming, writing SKILL.md, testing, iterating, and saving the skill to the repo. Use this whenever the user wants to build a new skill, capture a workflow as a skill, or says "make a skill for X", "turn this into a skill", or "new skill".
compatibility: Requires git. Deploy skills with `make install-system` in ai-skills (copy-only; see principles/deployment.md).
---




# Skill Creator

Your job is to guide the user from a rough idea to a working, well-crafted skill. The process is:

1. Capture intent
2. Interview and research
3. Name the skill
4. Write SKILL.md
5. Create the skill file
6. Test it
7. Iterate until the user is satisfied

Meet the user where they are. If they have a half-formed idea, help them shape it. If they walk in with a draft, skip to testing. If they say "just vibe with me and skip the formalities", do that.

---

## 1. Capture Intent

Start by understanding what the user wants. If the current conversation already contains a workflow (tools used, sequence of steps, corrections made), extract answers from it first and ask the user to confirm rather than starting from scratch.

Answer these before moving forward:

- What should this skill enable Claude to do?
- When should this skill trigger? What would a user actually type to kick it off? (concrete phrases, not abstract descriptions)
- What's the expected output — a file, a set of actions, a conversation, something else?
- Does it need to interact with external tools, files, or APIs?

---

## 2. Interview and Research

Before writing anything, dig into edge cases and specifics. Good questions to explore:

- What does success look like? What would a bad output look like?
- What are the 2–3 most common things that could go wrong or be misunderstood?
- Are there existing skills this overlaps with? (Check `~/.claude/skills/` for names)
- Does the skill need bundled scripts, reference docs, or assets?

Check available MCP tools — if any are relevant to the skill's domain, note them for the `compatibility` field.

Don't move to writing until you have enough to make real decisions, not just fill in a template.

---

## 3. Name the Skill

Read `references/conventions.md` for the full naming rules and optional domain-prefix guidance. Key points:

- Format: `{domain}-{verb}` (preferred) or `{domain}-{noun}`; cross-cutting skills may omit a domain prefix (`git-ops`, `grill-me`)
- Lowercase letters and hyphens only, 1–64 characters, no leading/trailing/consecutive hyphens
- Must match the directory name exactly
- Add a `{context}-` prefix only when the skill is useless outside one scope; do not invent employer-specific prefix tables in public skills

Propose a name with a one-line explanation of the domain choice. If the user has a preference, use it — but flag if it violates the convention.

---

## 4. Write SKILL.md

Use this structure:

```
---
version: 1.0.0
principles_version: 1.0.0
last_updated: YYYY-MM-DD
updated_by: human
name: skill-name
description: [see below]
compatibility: [only if needed]
---

# Skill Title

[Brief orientation]

## Sections as needed
```

### Writing the description

The description is the primary trigger mechanism — Claude decides whether to activate a skill almost entirely based on it. Write it to answer two questions:

1. What does this skill do?
2. When should Claude use it? (specific user phrases, contexts, situations)

Lean slightly pushy: Claude tends to undertrigger skills, so err toward listing more situations where the skill applies rather than fewer. Include natural-language trigger phrases the user would actually type.

Max 1024 characters.

### Writing the body

- Keep SKILL.md under 500 lines; move detail into `references/` if needed
- Imperative form: "Do X", not "You should X"
- Explain the *why* behind non-obvious steps — don't just list instructions
- Skip comments that restate what the code does
- Avoid ALWAYS/NEVER in all-caps; instead explain the reasoning so it generalises

### Output formatting

Global formatting rules (ADHD-friendly: chunked output, bold key terms, ✓/✗/⚠️ status symbols, lead with the point) are in `~/.claude/CLAUDE.md` and apply automatically — do not repeat them in the skill body.

If the skill produces complex structured output (reports, audits, multi-section results), reference `references/formatting.md` in the skill's own `references/` directory for patterns specific to that output type.

---

## 5. Create the Skill File

Once the user approves the draft:

1. Create the directory under the ai-skills repo:

   ```bash
   mkdir -p ai/claude/skills/{name}
   ```

2. Write `SKILL.md` there (and `references/conventions.md` copy if this is a meta skill).

3. Create `scripts/`, `references/`, or `assets/` only if needed.

4. Run `make bootstrap-version` and `make manifest-update` from the ai-skills repo root.

5. Deploy: `make install-system` (or interim path in docs/ROADMAP.md).

6. Update `README.md` / `AGENTS.md` if the skill changes documented workflows.

7. Branch + PR in ai-skills — do not commit to `main` directly. Remind the user to reload Claude Code after deploy.

---

## 6. Test the Skill

Come up with 2–3 realistic test prompts — the kind of thing a real user would actually type. Share them with the user before running: "Here are the prompts I'd like to test. Do these look right?"

For each test prompt, follow the skill's own instructions to complete the task, then show the user the output. Be honest about what worked and what felt off.

Good test prompts are:

- Specific and concrete (include file names, context, personal details)
- Varied in phrasing (formal, casual, abbreviated)
- Focused on edge cases, not just the obvious happy path

---

## 7. Iterate

After the user reviews the test outputs, improve the skill based on their feedback.

When revising:

- **Generalise, don't overfit.** The goal is a skill that works for a million different prompts, not just the ones you tested. Resist adding rigid rules for specific cases; instead, explain the underlying principle.
- **Keep the prompt lean.** Remove instructions that aren't pulling their weight. If the skill is making Claude do unproductive things, cut the part causing it.
- **Explain the why.** Today's models respond better to understanding than to mandates. If you find yourself writing ALWAYS or adding rigid structure, step back and ask if you can explain the reasoning instead.

Repeat test → review → revise until the user is satisfied.

---

## 8. Description Optimization (optional)

After the skill is working well, offer to sharpen the description for better triggering. Walk through this with the user:

1. Write 8–10 "should trigger" prompts — varied phrasings, some casual, some edge cases
2. Write 8–10 "should not trigger" prompts — near-misses that share keywords but need something else
3. Review the set with the user and prune bad examples
4. Rewrite the description based on patterns in the edge cases
5. Update the frontmatter with the new description

The key signal: if a prompt is ambiguous about whether the skill applies, it's a useful test case. If it's obviously in or obviously out, it teaches you nothing.
