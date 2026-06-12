---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: brain-dump
description: Run a brain-dump intake session — accept raw items one at a time, hold them without acting, then ask a single round of clarifying questions across all items at once before creating tickets in batch. Use this when the user wants to dump a backlog of unstructured thoughts into tickets, or says "I want to do a brain dump", "let me drop some items", "I'll give you a list of things to ticket", "I need to dump my backlog", "I have a bunch of ideas to capture", "brain dump mode", or opens with "I'll drop them one at a time and let you know when I'm done".
compatibility: Requires at least one ticket system (GitHub Issues, GitLab Issues, Jira, or Linear) reachable via MCP or CLI.
---

# Brain Dump

Intake raw items quickly, ask questions once, create tickets in batch.

This skill is distinct from `issue-create`: it is an intake workflow for many loosely-formed items at once. Do not create tickets mid-intake, do not ask per-item questions, do not start routing until the user signals they are done.

---

## Phase 1 — Open the intake

When the skill triggers, say exactly this (or an equivalent that sets the same expectation):

> Ready. Drop your items — one at a time or in batches, whatever is easiest. I'll hold them all and ask questions at the end. Say "done" (or "that's it", "finished", "go") when you're ready to proceed.

Then wait. Do not prompt for more information. Do not summarise what you've heard. Do not number or organise items yet. Just acknowledge each drop with a brief neutral signal ("got it", "noted", "✓") so the user knows it landed.

---

## Phase 2 — Collect

Accept items in any format:

- Freeform sentences ("we need a thing that does X")
- Bullet dumps ("- fix the login bug\n- add export button\n- talk to Sarah about the API")
- Mixed prose and lists
- Code snippets, screenshots described in text, URLs

For each item received, extract a rough **intent** silently — but do not surface it yet. If an item is clearly two separate things, note that for Phase 3.

Continue until the user signals done. Treat "done", "that's it", "finished", "go", "ok create them", "let's go", "make the tickets", or any clear completion signal as the end of intake.

---

## Phase 3 — Clarify (one round only)

Show the user a numbered list of the items as you understood them. Keep each entry to one line — enough to confirm you captured it correctly. Then ask all clarifying questions in a single block.

Format:

```
Here's what I captured:

1. [one-line summary]
2. [one-line summary]
...

A few questions before I create the tickets:

- **Item 2**: Is this a bug or a feature request?
- **Item 4**: Which repo / project does this belong to? I see a few candidates.
- **Item 6**: This looks like two separate items — [X] and [Y]. Split them?
- **All items**: Default priority Medium — override any?
```

Ask only questions that affect routing, title, or priority. Do not ask questions you can answer yourself from context (e.g. don't ask which Linear team if there's only one). Keep this round to ≤6 questions. If you have no questions, skip this phase and say so.

Wait for the user's answers before proceeding.

---

## Phase 4 — Route

After the user answers (or if Phase 3 was skipped), determine the target ticket system for each item. Use this priority order:

1. **Explicit signal** — user said "this is a Linear ticket" or "goes in GitHub"
2. **Repo context** — if the item references a specific repo or codebase, use that repo's ticket system
3. **Conversation context** — if the session has been in a specific project context, default there
4. **Ask** — if genuinely ambiguous and it matters (e.g. no default system, or the item could go to work Jira or personal GitHub), ask once

For each item, note:
- Target system: GitHub / GitLab / Jira / Linear
- Target project/repo/board
- Type: bug / feature / chore / question / spike
- Priority: Urgent / High / Medium (default) / Low
- Title (one line, imperative or noun phrase)
- Body (2–4 sentence description if the raw item has enough context; otherwise minimal)

---

## Phase 5 — Confirm and create

Show the user the full batch before creating anything:

```
Ready to create N tickets:

1. [Title] → GitHub: owner/repo (bug, medium)
2. [Title] → Linear: Team / Project (feature, medium)
...

Create all? Or any changes first?
```

If the user approves, create tickets in batch. For each ticket:

- Use the appropriate MCP tool or CLI for that system
- Set title, body, type/label, and priority as determined in Phase 4
- Capture the returned ticket URL or ID

After all tickets are created, show a summary:

```
✓ Created N tickets:

1. [Title] — <url>
2. [Title] — <url>
...
```

If any creation fails, note it clearly and offer to retry or skip.

---

## Notes

- **No per-item interruptions during intake.** The value of this skill is frictionless capture. Interjecting mid-dump breaks the flow and defeats the purpose.
- **One clarification round.** Batching questions is what makes this faster than issue-create. If you missed something, it goes in a ticket comment — do not open a second round.
- **Public repo safety.** Before creating tickets in a public repo, check items for sensitive content (internal hostnames, credentials, internal ticket IDs used as examples). Flag any issues in Phase 3 rather than silently scrubbing.
