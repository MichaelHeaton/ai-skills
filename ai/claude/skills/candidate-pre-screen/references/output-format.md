---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: cursor
---


# Pre-screen output format

Use this structure for Phase A + B. Phase C replaces **Verdict preview** with **Final verdict** and adds the scorecard.

```markdown
# {Candidate name} — manager pre-screen prep

**Opening:** {role / client slot — from private context, not invented}
**Prior screener:** {name, date, one-line take — or "None provided"}
**Resume:** {filename or "pasted"}
**Phase:** {A / A+B / C}

---

## Verdict preview

→ **{Advance | Hold | Hard No | Needs live screen to decide}** — {one sentence rationale}

---

## Authenticity signals

| Signal | Confidence | Notes |
|--------|------------|-------|
| ... | High / Medium / Low | ... |

**False-positive note:** {when applicable — coach, strong writer, language}

---

## ATS / keyword signals

| Signal | Severity | Notes |
|--------|----------|-------|
| ... | High / Medium / Low | ... |

⚠️ ATS optimization alone is not disqualifying — note when combined with other gaps.

---

## JD fit ({opening})

| Criterion | Resume claim | Prior screener | Gap |
|-----------|--------------|----------------|-----|
| ... | ... | ... | ... |

**Role recommendation if pass:** {slot or "neither confidently"}

---

## Priority probes (ranked)

### 1. {Topic} *(highest risk)*

> "{exact question to ask}"

**Good sounds like:** ...
**Bad sounds like:** ...

{repeat for 3–5 probes}

---

## During-call watch list

- {observable behaviors — monitor fixation, pause-then-polish, can't simplify, etc.}

---

## Open questions

- [ ] ...

---

## Handoff gate

{handoff_gate from local.json, or default: Do not forward to client hiring manager until this pre-screen completes.}
```

## Phase C additions

Replace verdict preview section with:

```markdown
## Final verdict

**{Advance | Hold | Hard No}** — {summary}

## Scorecard

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Technical | Pass / Fail / Partial | |
| Willingness to learn | Pass / Fail / N/A | |
| Client fit | Pass / Fail | |
| Team fit | Pass / Fail | |

## Open questions — closed

- [x] {question} → {outcome}
```

## Formatting

- Lead with the verdict line — screener skims under time pressure
- Use tables for scanability
- Keep probe wordings **copy-paste ready** for the interview
- Do not include wikilinks in output unless writing directly to memex at user request
