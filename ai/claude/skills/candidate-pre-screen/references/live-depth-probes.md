---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: cursor
---




# Live depth probes

Techniques for detecting scripted answers, screen-reading, or AI assist during a video screen. Generate **specific questions** from the candidate's resume and prior screener notes — this file defines *how*, not a generic question bank.

## Probe techniques

| Technique | How to use |
| --------- | ---------- |
| **Depth ladder** | Broad → narrow → "what broke?" — stop when answers stay generic. |
| **Ownership boundary** | "What did *you* build vs the platform/security team?" — deflates inflated bullets. |
| **Contradiction probe** | Anchor to prior screener: "Rob said limited Python — walk me through your Django work at {employer}." |
| **Mid-answer pivot** | "Stop — explain that in one sentence for a junior." Scripted answers resist simplification. |
| **Whiteboard verbal** | "Talk me through {architecture from resume} — no slides, just talk." |
| **Read-back trap** | Ask the same concept two ways; surface answers stay identical and shallow. |
| **Failure story** | "Tell me about a deployment or migration that went wrong." Polished resumes rarely include real failures. |
| **Mechanism check** | Scenario with one correct mechanism (e.g. TF tags via `default_tags`, provider `tags`, or shared module) — buzzwords without mechanism = fail. |

## Calibrating probes to flagged risks

| Flag | Probe type |
| ---- | ---------- |
| Python mismatch | Ownership + simple script or "read this snippet" |
| TF self-rate high | Drift story, then tag/module scenario |
| Tri-cloud resume, one cloud validated | Concrete project on the unvalidated cloud |
| GenAI bullets | What you built vs platform team; name models/tools you operated |
| Scope inflation (FedRAMP, Zero Trust) | Shrink scope — what did you personally implement |

For each probe in output, include **good sounds like** / **bad sounds like** so the screener knows when to stop digging.

## During-call watch list (observable)

Note behaviors — do not diagnose intent:

- Eyes fixed on second monitor; typing during answers
- Long pause, then polished paragraph (possible script or feed)
- Cannot simplify after direct request
- Re-reads resume bullet verbatim when asked for story
- Repeated requests to repeat basic questions — log separately from technical fail (language vs comprehension)

Log **video/logistics issues** separately from technical verdict (lighting, connection) for fairness.

## When to stop the screen early

If two priority probes fail at mechanism level and delivery is consistently scripted, note **Hard No lean** — screener may end early to protect calendar. Confirm with user preference if unclear.
