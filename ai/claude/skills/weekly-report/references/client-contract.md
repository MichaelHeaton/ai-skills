---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---




# Client-contract weekly (deck)

Config: `weekly_reports.client_contract` in `local.json`.

Output path: `output_file` in that block (default pattern `Outputs/Weekly/Client-Contract-Weekly-YYYY-MM-DD.md`).

## Coverage period

Ask how many weeks and the end date. One block per week (`## Week of YYYY-MM-DD`).

## Sources

Search the vault for the coverage window — paths come from your private config (`memex_format_ref`, inbox, CRM, issue labels). Ask the user to fill gaps.

Classify signals: **Quote**, **Impactful**, **WIN**.

## Deck sections

Use `display_name` from config for row prefixes (e.g. `ClientName — Mon DD, YYYY`).

Typical sections (adjust to your format ref):

1. Account overview — one paragraph
2. Client and employee quotes — blockquote; follow `quote_attribution_note`
3. Impactful alerts / tickets / projects
4. WINS — past tense, measurable

Keep leadership-safe; exclude internal HR/comp/relationship commentary per your format ref.

## Save

Paste-ready body without wikilinks. Internal `## Sources consulted` at bottom for you only.

## Wrap-up

- Open `sharepoint_deck_url` if set
- Respect `deadline_note`
- Comment on `recurring_github_issue` if set
- Update `last_updated` in your format reference doc
