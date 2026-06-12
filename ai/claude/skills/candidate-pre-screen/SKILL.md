---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: cursor
name: candidate-pre-screen
description: Manager pre-screen for contractor or FTE candidates — resume authenticity and ATS signals, JD fit vs prior screener notes, ranked live-interview probes, and post-call debrief. Routes opening criteria from private local.json and optional vault hiring folders. Triggers on pre-screen, candidate screen, resume review for hiring, interview prep for candidate, manager screen, UV screen, screen this resume, prep my interview with, candidate debrief, advance to client, hard no on candidate, or when user pastes a resume with hiring context.
compatibility: Optional resume PDF or vault paths; ~/.config/ai-skills/local.json for hiring context routing.
---




# Candidate Pre-Screen

Support a **manager pre-screen** before forwarding a candidate to a client hiring manager. Three phases — run the phases the user asks for; default to **A + B** when they say "pre-screen" without specifying.

| Phase | Purpose |
| ----- | ------- |
| **A — Resume intel** | Authenticity + ATS signals, JD fit table |
| **B — Interview prep** | Ranked probes + during-call watch list |
| **C — Debrief** | Post-call verdict, scorecard, open questions closed |

Resume-only phases **never auto-advance** a candidate. Final forward/hold/no decisions require a live screen (Phase B executed, Phase C when done).

---

## Step 0 — Load context

Read `~/.config/ai-skills/local.json` → `candidate_pre_screen` when present:

| Key | Use |
| --- | --- |
| `memex_repo_path` | Root for vault hiring folders and CRM profiles |
| `context_root` | Hiring resources dir under memex (openings, JD comparisons) |
| `openings_glob` | Glob for active opening folders (default `Hiring-*`) |
| `crm_person_path` | Relative path to candidate CRM notes (default `CRM/Person`) |
| `handoff_gate` | Text to repeat in output — client forward blocked until this screen completes |
| `screening_calendar_note` | Optional scheduling preference for the screener |

Resolve opening criteria from the **first source that exists**:

1. User-named opening or JD comparison file in `context_root`
2. README or `*-JD-Candidate-Comparison-*` under matching `openings_glob` folder
3. User-pasted job description or role requirements in chat

Load prior screener notes when available (recruiter summary, Slack paste, or `*-Screening-*.md` in the opening folder). If missing and a recruiter screen is part of the process, ask once for their summary before Phase B.

Load the resume from: pasted text, attached PDF, or vault path under `context_root`.

Read reference heuristics (do not skip):

- [references/resume-authenticity-signals.md](references/resume-authenticity-signals.md)
- [references/ats-keyword-patterns.md](references/ats-keyword-patterns.md)
- [references/live-depth-probes.md](references/live-depth-probes.md)
- [references/output-format.md](references/output-format.md)

---

## Step 1 — Route phase

| User intent | Phases |
| ----------- | ------ |
| "pre-screen", "resume review", paste resume + opening | **A + B** |
| "interview prep", "questions for", before a scheduled call | **B** (use prior A output or run A first if resume new) |
| "debrief", "how did the screen go", post-call notes | **C** |
| Full cycle in one thread | **A → B → C** as each stage completes |

If opening is ambiguous, list folders matching `openings_glob` or ask which role slot (when the private JD comparison defines multiple).

---

## Step 2 — Execute

### Phase A — Resume intel

Score **authenticity signals** and **ATS signals** separately — they are related but not the same problem. Use confidence (High / Medium / Low) or severity; explain *why* for each row.

Build the **JD fit** table: resume claim | prior screener validated | gap. Flag resume > conversation mismatches prominently.

Set **verdict preview**: `Advance` / `Hold` / `Hard No` / `Needs live screen to decide`. Resume-only → always include "Needs live screen" unless user explicitly wants a paper-only lean (note that live confirmation is still required before client handoff).

### Phase B — Interview prep

Generate **3–5 priority probes** ranked by risk. Anchor each probe to:

- A flagged authenticity or ATS signal
- A prior-screener contradiction (e.g. resume claims Python, screener said limited Python)
- A must-have from the opening criteria

For each probe include: the question, **what good sounds like**, **what bad sounds like**.

Add **during-call watch list** from [references/live-depth-probes.md](references/live-depth-probes.md).

Copy **open questions** as unchecked items for the live screen.

### Phase C — Debrief

After the user reports call outcomes:

- Final verdict: **Advance** / **Hold** / **Hard No**
- Scorecard: Technical | Willingness to learn | Client fit | Manager-team fit (adjust labels to opening)
- Close open questions from Phase B with outcomes
- Repeat **handoff_gate** — explicit forward/no-forward to client hiring manager
- Suggest vault paths for persistence (`CRM/Person/{Name}.md`, `{opening}/*-Screening-*.md`) when `memex_repo_path` is configured — do not write files unless the user asks

---

## Step 3 — Output

Follow [references/output-format.md](references/output-format.md). Lead with **verdict preview** (A/B) or **final verdict** (C).

---

## Principles

- **Signals, not verdicts** — AI-written or ATS-optimized resumes are informational; do not auto-reject on polish alone.
- **False positives** — strong writers, career coaches, and non-native English can mimic AI tells; probe with simplification and depth, not accent or grammar alone.
- **Prior screener respect** — treat recruiter notes as hypotheses to confirm or clear, not gospel.
- **No PII in public repo** — candidate names and outcomes stay in chat or private vault; never commit screening notes to ai-skills.
- **Client handoff gate** — echo `handoff_gate` from local.json when set; default wording is acceptable when unset.
