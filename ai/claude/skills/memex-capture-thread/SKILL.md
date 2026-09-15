---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: memex-capture-thread
description: Capture a pasted Slack thread (or similar raw conversation) into the memex vault in one pass — a dated CRM/Meeting note, a relevant wiki-page checklist/status update, a Wiki/log.md entry, both Raw/_task-index.jsonl and Raw/_GitHub-Issues-log.jsonl ledger appends, and any implicated CRM/Person profile touches — replicating the "Capture X (Slack, date)" pattern that otherwise gets re-derived by hand from prior commits every time. Use when someone pastes a Slack thread, DM exchange, or similar conversation capture into a memex session and asks to log it, write it up, "capture this thread", "add this to the vault", or "turn this into a note" — anywhere the memex repo's wiki/CRM/ledger structure applies. Distinct from vault-support (HashiCorp Vault support-triage — unrelated domain, name collision avoided deliberately, see Naming note below), issue-create (ticket creation only, no wiki/ledger/meeting-note side), and memex-dump (quick capture straight to a ticket, does not write structured vault notes).
compatibility: Requires a memex-style vault repo with CRM/, Wiki/, and Raw/ directories already established.
---

# Memex Capture Thread

A pasted Slack thread carries a feature request, a resolution, a decision, or a status change that needs to land in five places at once — not just one ticket. This skill drafts all five in one pass instead of re-deriving the convention from a prior "Capture X (Slack, date)" commit by hand.

## Naming note

This skill was originally proposed as `vault-capture`. `ls ai/claude/skills/ | grep -i vault` turned up `vault-support` (HashiCorp Vault support-triage — unrelated domain) and `vault-ssh-fallback`. To avoid confusion between "memex vault" and "HashiCorp Vault," this skill is named `memex-capture-thread` instead. If a future rename convention introduces a `memex-` prefix standard, rename this along with it.

## When to use

The user pastes a Slack thread, DM exchange, or similar raw conversation into a memex session and wants it captured — not just summarized. Signals: "capture this thread", "log this to the vault", "add this to memex", or a paste immediately followed by "can you write this up."

## Step 1 — Read the thread and extract the shape

From the pasted conversation, identify:

- **Date** of the thread (use the paste's own timestamps if present, otherwise ask)
- **Topic** — a short slug for filenames (e.g. `cv-mtb-feature-request`)
- **Participants** — map to existing `CRM/Person/` profiles where possible
- **Outcome** — feature request, bug resolution, decision, status change, or open question
- **Follow-up work implied** — if real actionable work is implied, flag for Step 6

## Step 2 — Find the right existing wiki page

Search `Wiki/` for the project or topic the thread relates to (`grep -ril <topic-keyword> Wiki/`). Do not create a new wiki page speculatively — attach the update to the existing project/backlog page unless none exists, in which case ask before creating one.

## Step 3 — Draft the dated meeting note

Write `CRM/Meeting/<date>-Slack-<topic>.md` (date as `YYYY-MM-DD`, topic as a kebab-case slug). Include:

```markdown
# <date> — Slack: <Topic>

**Participants:** <names, linked to CRM/Person/ where profiles exist>
**Context:** <one-line summary of what prompted the thread>

## Thread summary

<condensed narrative of the exchange — not a verbatim paste>

## Outcome

<decision, resolution, or status change>

## Follow-up

<any implied action items, or "None">
```

## Step 4 — Update the relevant wiki page

Edit the wiki page found in Step 2: update its checklist (check off an item the thread resolved) or its status section (note the change), with a short inline reference back to the new meeting note (`See CRM/Meeting/<date>-Slack-<topic>.md`).

## Step 5 — Append the log and ledger entries

Three appends, all in one pass:

1. `Wiki/log.md` — one line: `<date> — Captured Slack thread on <topic>: <one-line outcome>. See CRM/Meeting/<date>-Slack-<topic>.md.`
2. `Raw/_task-index.jsonl` — append a JSON line recording the meeting note path, date, and topic, matching the existing entries' schema (read a recent entry first to match fields exactly).
3. `Raw/_GitHub-Issues-log.jsonl` — append a JSON line only if Step 6 opens a tracking issue; otherwise skip this file for this capture.

## Step 6 — CRM/Person touches and optional tracking issue

For each participant with an existing `CRM/Person/<name>.md` profile, add a short note under an "Interactions" or "Log" section referencing the new meeting note.

If the thread implies real follow-up work (not just a resolved discussion), open a tracking issue via the **`issue-create`** skill — never call a ticketing MCP tool directly. Pass the meeting note path as context so the ticket links back to it. Record the resulting issue in `Raw/_GitHub-Issues-log.jsonl`.

## Step 7 — Confirm before writing

Before writing any file, show the user the planned file list (meeting note path, wiki page to be touched, ledger files, any CRM/Person files) and the one-line log.md entry. Proceed only after confirmation — this touches five-plus files in one pass and a wrong topic slug or wrong wiki page is easy to miss until it's already committed.
