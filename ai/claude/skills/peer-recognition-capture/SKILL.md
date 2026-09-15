---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: peer-recognition-capture
description: Detects incoming praise or recognition content about a teammate (an email, a chat message, a Slack DM) and files it as a dated note on that person's CRM/person-record in the personal vault, so it isn't lost or left to hand-transcription. When the praise can't go through a formal recognition program — e.g. the recipient's employment type (contractor, vendor) makes them ineligible — routes it to their manager instead and records the routing rationale alongside the note. Trigger on "someone praised", "got a compliment about", "recognition for", "log this praise", "file this feedback about [person]", "this should go in their CRM note", "nice note about [teammate]", "kudos for", or any incoming message whose content is substantively positive feedback about a specific named colleague's work.
compatibility: Requires an Obsidian vault (or equivalent CRM/person-record store) with a per-person note file, path from local.json.
---

# Peer Recognition Capture

Praise about a teammate arrives informally — an email, a Slack message, a passing comment relayed secondhand — and without a place it's supposed to land, it gets hand-transcribed into a CRM note (or forgotten). This skill gives that a repeatable path: detect it, extract it, file it, and if it can't go through a formal recognition program, route it to the right person with the reason recorded.

## 1. Detect and extract

When incoming content (email, chat, forwarded message) is substantively praise or recognition about a specific named colleague's work, extract:

- **Who is being praised** — the teammate's full name
- **Who is praising them** — sender/author, and their relationship to the teammate (customer, cross-team peer, stakeholder)
- **What specifically is being praised** — the concrete work, behavior, or outcome, not just "great job"
- **Date** — when the praise arrived, not when it's being filed

If the content is vague appreciation with no concrete detail ("thanks for everything"), still capture it, but note the lack of specifics rather than inventing detail to pad the note.

## 2. Determine the routing path

Check whether the praised person is eligible for the sender's or company's formal recognition program (if one exists and is known):

- **Eligible** — note that the formal program is the primary path; this skill's vault note is a supplementary record, not a replacement for submitting it there. If the user wants help drafting the formal-program submission, that's a separate ask — this skill only files the vault record.
- **Not eligible** (common cause: the recipient's employment type — contractor, vendor, non-employee — falls outside the program's scope) — the praise routes to the teammate's manager (the vault user, typically) instead of the formal program. Record the specific ineligibility reason in the note, not just "routed to manager."
- **Unknown/unclear** — ask the user which path applies rather than guessing eligibility.

## 3. File the CRM/person-record note

Append a dated entry to the teammate's CRM/Person note in the vault (path resolution: `peer_recognition.vault_path` in `~/.config/ai-skills/local.json`, else the vault's standard `CRM/People/<name>.md` convention):

```markdown
## Recognition — YYYY-MM-DD

**From:** <sender name/role>
**What:** <specific praise content, concrete detail>
**Routing:** <Formal program submitted | Routed to manager — reason: <eligibility reason>>
```

Confirm the target file exists before writing — if the person has no existing CRM note, ask whether to create one rather than silently generating a new file with unverified formatting.

## 4. Confirm with the user

Show the drafted note entry before writing it, and confirm the routing rationale is accurate (especially the eligibility reason, which reflects a real policy the user may want to phrase precisely). Do not send anything on the user's behalf — filing the vault note is this skill's only side effect; any outbound message (thanking the sender, telling the teammate) is a separate ask.

## What this skill is not

- Not a formal recognition-program submission tool — it records that praise arrived and where it was routed, it doesn't fill out or submit the program's own form.
- Not an outbound-messaging skill — drafting a thank-you or forwarding the praise to the teammate is a separate request; pair with `comms-write` if the user wants that.
- Structured the same way as this repo's other personal/vault-domain skills (`interview-debrief`, `contract-renewal-tracking`): collect context, decide a path, file a dated vault note, confirm before writing.
