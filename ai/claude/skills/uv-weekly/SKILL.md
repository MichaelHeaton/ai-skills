---

name: uv-weekly
description: Draft the UV Dedicated Defense weekly deck update (slides 8-10) for the Adobe account. Guides Michael through collecting recent signals from vault captures, drafting client-ready copy for Quotes, Impactful Alerts/Projects, and WINS, and saving a paste-ready output file to Outputs/Weekly/. Trigger on: "UV weekly", "weekly repost", "dedicated defense update", "update the DD deck", "run UV weekly report", "slides 8-10", "dedicated defense slides", "weekly deck", or any request to prepare or catch up on the Dedicated Defense weekly submission. The meeting cadence is every 3 weeks but updates should go in the deck weekly — if multiple weeks are being caught up, produce one labeled block per week.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# UV Weekly — Dedicated Defense Deck Update

Produces client-ready copy for slides 8-10 of the UV Dedicated Defense PowerPoint deck in SharePoint. Output saved to `Outputs/Weekly/{end-date}/dedicated-defense-slides-8-10.md` in the vault, ready to paste into the deck.

**Deck (SharePoint):** https://uvcyber-my.sharepoint.com/:p:/p/aabid_daud/IQDdKXmGqO5rQKJpbqvgunWBAcx_tqZqQl-LDrmsNIfbLoQ
**Recurring issue:** https://github.com/MichaelHeaton/memex/issues/571
**Format reference:** `Raw/Resources/UV-Cyber/Dedicated-Defense-Weekly-Report-Deck.md`
**Deadline:** Thursday EOD each week — Atif's admin pulls for the Weekly Momentum email to ELT/SLT on Fridays.

---

## Step 1 — Establish coverage period

Ask: "How many weeks are we catching up on, and what's the end date of the last week?"

If multiple weeks: produce one clearly labeled block per week (e.g. `## Week of 2026-05-05`). Each week gets its own Quotes / Impactful / WINS entries. A week with nothing real to report gets a note — don't pad with stale content.

---

## Step 2 — Gather signals

Search the vault for activity within the coverage window:

- `Inbox/Generic/` — daily captures, Slack extracts, CES vault threads
- `Raw/Resources/UV-Cyber/` — existing report notes and bullets

Ask the user to confirm or add anything the search misses (verbal briefing, Slack DMs, etc.).

For each usable signal, classify it:
- **Quote** — verbatim or paraphrased client/employee recognition (must be safe for senior leadership)
- **Impactful** — significant delivery, risk management, or operational intensity
- **WIN** — completed outcome, past tense, measurable where possible

---

## Step 3 — Draft slide copy

Produce three clearly labeled blocks per week, ready to paste into the deck. Follow the tone rules from the format reference — these go to UV ELT/SLT via the Weekly Momentum report.

**Slide 8 — Client and Employee Quotes**
- Format: `Adobe — [Date]\n> [One paragraph, client/public voice only]`
- Always attribute who said it — name or role (e.g. "Drew Wright, Adobe engineering manager" or "Tyler Jacobsen"). Aabid confirmed this is required.
- ✗ Internal relationship labels ("right-hand", etc.)
- ✗ UV vs FTE comparisons, comp, retention, meeting load

**Slide 9 — Impactful Alerts/Tickets/Incidents/Projects**
- Format: `Adobe — [Date]\n> [One tight factual paragraph per row]`
- One strong row beats five stale ones — omit anything without a fresh signal for that week

**Slide 10 — WINS**
- Format: `Adobe — [Date]\n> [Past tense, outcome-oriented, measurable where possible]`
- ✗ 1v1s completed, pay cycle events, retention discussions — not WIN-voice

---

## Step 4 — Save output

Write the paste-ready content (Section A only — no internal B-section links) to:

```
Outputs/Weekly/{end-date}/dedicated-defense-slides-8-10.md
```

Use the end date of the last week covered as the folder name (YYYY-MM-DD).

Append a brief internal note at the bottom of the file (clearly marked `## Internal — do not paste`) listing any vault captures or notes that sourced the content, for your own cross-reference.

---

## Step 5 — Wrap up

After saving:

1. Link to the output file.
2. Remind Michael to open the SharePoint deck and paste the content into slides 8-10 **before Thursday EOD**.
3. Update `last_updated` in `Raw/Resources/UV-Cyber/Dedicated-Defense-Weekly-Report-Deck.md` to today's date.
4. Remind Michael to add a comment to [GitHub Issue #571](https://github.com/MichaelHeaton/memex/issues/571) noting which weeks were submitted.
