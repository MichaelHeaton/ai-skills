---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-11
updated_by: claude
name: contract-renewal-tracking
description: Structured workflow for capturing and tracking contractor or employee compensation and contract renewals. Collects renewal context, creates or updates a CRM/Person vault note, creates or updates a Wiki/Concepts tracking note with the renewal timeline, opens a GitHub Issue in Memex as a follow-up reminder, and drafts an outbound Slack or email message — all with cross-links between artifacts. Triggers on "comp review", "renewal prep", "contract renewal", "compensation renewal", "staffing renewal", "prep for renewal", "renewal coming up", "contract coming up", "renewal for", "reviewing comp for", "prepare for comp discussion", "renewal season".
compatibility: Requires gh CLI (Memex issues), Obsidian vault at path from local.json, ~/.config/ai-skills/local.json.
---

# Contract Renewal Tracking

Capture a contract or compensation renewal in one pass: vault note → tracking note → Memex issue → outbound message. All artifacts are cross-linked.

---

## Step 1 — Collect context

Gather from the user's message or ask for what's missing:

| Field | Required | Notes |
| ----- | -------- | ----- |
| **Person** | ✓ | Full name and role |
| **Renewal type** | ✓ | Contract renewal / comp review / FTE offer |
| **Current terms** | ✓ | Rate, title, end date (or last review date) |
| **Renewal date / deadline** | ✓ | When action is needed by |
| **Context** | ✓ | Why this came up (Slack, email, 1:1, proactive) |
| **Target terms** | optional | Proposed new rate, title, or scope |
| **Notes / concerns** | optional | Anything relevant to the decision |

If any required fields are missing, ask in a single batch — don't ask one at a time.

---

## Step 2 — CRM / Person vault note

Read `vault.crm_path` from `~/.config/ai-skills/local.json` to locate the People directory.

**File path**: `<crm_path>/People/<LastName-FirstName>.md`

If the file exists: read it and update the relevant section (don't duplicate existing entries).
If it doesn't exist: create it using the template in [references/crm-person-template.md](references/crm-person-template.md).

Add or update a `## Contract & Comp` section with:

```markdown
## Contract & Comp

| Date | Type | Terms | Status |
| ---- | ---- | ----- | ------ |
| <renewal-date> | <renewal-type> | <terms summary> | In Review |
```

Note the vault note file path — you'll need it for cross-linking.

---

## Step 3 — Wiki tracking note

Read `vault.wiki_path` from `local.json` to locate the Concepts/Tracking directory.

**File path**: `<wiki_path>/Contracts/<LastName-FirstName>-renewal-<YYYY>.md`

If the file exists: append a new renewal entry.
If it doesn't exist: create it using the template in [references/wiki-tracking-template.md](references/wiki-tracking-template.md).

Include:

- Person, role, renewal type, current terms, target terms
- Renewal deadline
- Timeline (today's date → deadline, with any intermediate milestones if known)
- Cross-link to the CRM Person note: `[[People/<LastName-FirstName>]]`

---

## Step 4 — Memex issue

Create a GitHub Issue in Memex as a follow-up reminder:

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
gh issue create \
  --repo ${GITHUB_PERSONAL_USER}/memex \
  --title "Renewal: <FirstName LastName> — <renewal-type> by <renewal-date>" \
  --label "domain/work-primary,priority/high" \
  --body "<issue body — see below>"
```

**Issue body**:

```markdown
## Renewal context

**Person:** <name> (<role>)
**Type:** <renewal-type>
**Deadline:** <renewal-date>
**Current terms:** <summary>
**Target terms:** <summary or TBD>

## Context

<how this came up>

## Related vault notes

- CRM: `<crm-note-path>`
- Tracking: `<wiki-tracking-note-path>`

## Actions

- [ ] Confirm budget / approval
- [ ] Draft offer or renewal terms
- [ ] Send to <person or recruiter>
- [ ] Update vault note with outcome
```

Capture the returned issue URL and number.

**Back-link to vault notes**: After creating the issue, append the issue link to both the CRM note and the tracking note under a `## GitHub Issues` section.

---

## Step 5 — Draft outbound message

Draft a Slack or email message appropriate for the renewal type:

- **Contract renewal**: message to the contractor or their agency confirming intent and asking for updated W9 / MSA if needed
- **Comp review**: message to the person's manager or the person directly (ask which) with proposed terms and a clear ask
- **FTE offer**: recruiting-style message with terms and next-step timeline

Deliver the draft in a fenced ` ```plain ` block, ready to paste.

Ask: "Should I send this to the person directly or to their manager / recruiter?"

---

## Step 6 — Confirm and summarize

Report:

- ✓ CRM note: path and whether created or updated
- ✓ Tracking note: path and whether created or updated
- ✓ Memex issue: #NNN link
- ✓ Outbound message: format (Slack/email) and recipient
- → Next step: what the user needs to do before the deadline
