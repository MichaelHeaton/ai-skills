---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-11
updated_by: claude
name: interview-debrief
description: Post-interview debrief and decision capture — analyze interview notes, map signals to role criteria, generate a structured scorecard, draft a hiring recommendation (advance / hold / decline), and capture the decision in the vault. Complements candidate-pre-screen (pre-screen fires before, interview-debrief fires after). Triggers on "screen debrief", "post-interview feedback", "candidate feedback", "hard no on", "advance to next round", "debrief for", "scorecard for", "my notes from the interview", "write up my feedback", "hiring decision for", "should we advance", "interview write-up".
compatibility: Optional vault paths from local.json; candidate-pre-screen skill for prior context.
---

# Interview Debrief

Post-interview analysis in three phases. Run the phases the user requests; default to **A + B + C** when they say "debrief" without specifying.

| Phase | Purpose |
| ----- | ------- |
| **A — Signal summary** | Distill notes into strengths, concerns, open questions |
| **B — Scorecard** | Map signals to role criteria; structured scoring |
| **C — Decision capture** | Recommendation, vault note, optional outbound message |

---

## Step 1 — Collect context

Gather from the user's message or ask for what's missing:

| Field | Required | Notes |
| ----- | -------- | ----- |
| **Candidate name** | ✓ | |
| **Role** | ✓ | Title or JD reference |
| **Interview type** | ✓ | Phone screen / technical / loop / hiring manager |
| **Interviewer** | ✓ | Who conducted this interview (often the user) |
| **Notes / transcript** | ✓ | Paste raw notes, a transcript excerpt, or describe what you remember |
| **Role criteria** | optional | JD requirements, or load from vault if available |
| **Prior debrief context** | optional | Earlier rounds, pre-screen summary from candidate-pre-screen |

If notes are vague or very short, ask: "Any specific moments or answers that stood out — positive or negative?"

---

## Phase A — Signal summary

Distill the notes into three buckets:

### Strengths

Concrete signals from this interview that support the candidate moving forward. One sentence per signal; cite the specific moment or answer if you can.

### Concerns

Specific gaps, red flags, or unanswered questions. Be direct — a vague concern is less useful than a blunt one. Include "open questions" (things you couldn't probe in this session) in a sub-list.

### Fit assessment (qualitative)

One paragraph: given the signals above, how does this candidate feel for the role? Do not score yet — this is narrative.

---

## Phase B — Scorecard

Map signals to the role's stated criteria. If no criteria were provided, infer standard criteria for the role type (e.g. for engineering: technical depth, communication, problem-solving, ownership).

| Criterion | Signal | Rating |
| --------- | ------ | ------ |
| *criterion* | *specific evidence from this interview* | ✓ Strong / ~ Mixed / ✗ Weak / ? Not assessed |

**Overall signal**: Strong / Mixed / Weak (one word, based on the table).

---

## Phase C — Decision and capture

### Recommendation

State one of:

- **Advance** — proceed to next round or extend offer
- **Hold** — more information needed before deciding; specify what
- **Decline** — not a fit; specify the primary reason(s)

Include 2–3 sentences of rationale. Be direct — a recommendation with weak rationale gets ignored.

### Vault note

Read `vault.crm_path` from `~/.config/ai-skills/local.json`.

**File**: `<crm_path>/People/<LastName-FirstName>.md`

If the file exists: read it and append under `## Interview History`.
If it doesn't exist: create a minimal stub (name, role, date) — do not run the full contract-renewal-tracking flow for a candidate.

Append:

```markdown
## Interview History

### <interview-type> — <YYYY-MM-DD>

**Interviewer:** <name>
**Recommendation:** <Advance / Hold / Decline>
**Rationale:** <2-3 sentences>

**Strengths:** <bullet list>
**Concerns:** <bullet list>
```

### Optional: outbound message

If the user asks, draft a message to the recruiter or hiring loop:

- **Advance**: brief note with your recommendation and any areas to probe in the next round
- **Decline**: respectful note with high-level rationale (avoid protected-class language)
- **Hold**: note specifying what additional signal is needed

Deliver in a fenced ` ```plain ` block.

---

## Step N — Confirm

Report:

- Phase(s) completed
- ✓ Vault note: path and whether created or updated
- ✓ Recommendation: Advance / Hold / Decline
- → Next step: what the user needs to do (submit scorecard, send message, schedule next round, etc.)
