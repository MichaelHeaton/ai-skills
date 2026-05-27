---

name: vault-support
description: "Analyze an internal vault support Slack thread to fact-check the support bot, identify documentation gaps, and generate knowledge-extraction questions. Use when the user pastes a Slack message or thread from the vault support channel (see local config) — even without extra context. Triggers on: vault questions, bot responses, AppRole issues, policy PRs, KV2 questions, cross-path access, seal problems, onboarding questions pasted from Slack."
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# Vault Support Analyzer

## Step 0 — Load local config

Read `~/.config/claude-skills/local.json` ([references/local-config.md](../../../references/local-config.md)):

- `slack.vault_support_channel`
- `repos.work_docs` → `${WORK_DOCS_REPO}`
- `repos.work_skills` → `${WORK_SKILLS_REPO}` (optional)

## Processing Mode

**Default (foreground):** Run all steps inline. Best for Case A triage (needs a Slack response drafted), ambiguous threads, or when Michael wants to discuss findings before pushing.

**Background mode:** When Michael adds `--bg`, says "background", or says "run in background" after pasting a thread — confirm receipt and immediately spawn a background agent to handle Steps 3–8. Return control to Michael right away.

Use background mode for Case B threads where the team already resolved it and no discussion is needed before logging.

**How to spawn the background agent:**

1. Confirm receipt: *"Got it — triaging in the background. I'll notify you when the test case and Confluence push are done."*
2. Extract from the thread: the verbatim question, a 5-word title slug, and relevant tags.
3. Spawn via the Agent tool with `run_in_background=True`. The prompt must be fully self-contained — the agent has no session context. Use this template:

```
## Step 0 — Load local config

Read `~/.config/claude-skills/local.json` ([references/local-config.md](../../../references/local-config.md)):

- `slack.vault_support_channel` — channel name for triage context
- `repos.work_docs` — documentation repo path (working directory)
- `repos.work_skills` — customer-facing skills repo, if applicable

You are processing a vault support Slack thread for the triage system.
Working directory: `${WORK_DOCS_REPO}` (from local config)

## Thread (verbatim)

{PASTE_FULL_THREAD_HERE}

---

## Your tasks — complete all steps in order:

### Step 1 — Search work docs repo
cd ${WORK_DOCS_REPO}
python3 scripts/ask.py "{VERBATIM_QUESTION}" --context-only --top 8
Read the top 3 matching files in full.

### Step 2 — Analyze
Classify: Case A (no team reply) or Case B (team replied).
Determine sherlock_score: poor | partial | good | na
Determine team_reply_vs_sherlock: confirmed | expanded | corrected | no-reply | na
Identify miss_reasons, question_type, product_area, resolution_source.

### Step 3 — Create test case
python3 scripts/add_test_case.py \
  --title "{SHORT_TITLE}" \
  --question "{VERBATIM_QUESTION}" \
  --source "vault-support Slack" \
  --tags "{TAGS}" \
  {--slack-permalink "{PERMALINK}" if available}

Then open the created file and fill in all sections:
- frontmatter fields (sherlock_score, miss_reasons, question_type, product_area, resolution_source, team_reply_vs_sherlock)
- ## Sherlock Response (verbatim from thread)
- ## Correct Answer
- ## Why Sherlock Missed It (check the right box)
- ## Related Docs in This Repo
- ## Gap Actions (both work docs repo and customer skills repo actions)
Set status: analyzed.

### Step 4 — Regenerate report
python3 scripts/generate_report.py

### Step 5 — Push Confluence
export $(cat .env | xargs)

# Wiki findings page
python3 scripts/pull_page.py --page-id 3840522815 --output-dir /tmp/confluence-pull
# Edit /tmp/confluence-pull/wiki-findings-and-proposed-changes.md:
#   - Add row to the current session's index table (next available item number)
#   - Add detailed edit section above the most recent existing session's block
#   - Update Sherlock Performance Report thread count in Companion Docs table
python3 scripts/push_page.py /tmp/confluence-pull/wiki-findings-and-proposed-changes.md

# Sherlock report
python3 scripts/pull_page.py --page-id 3843166847 --output-dir /tmp/confluence-pull
# Replace body (keep frontmatter) with full content of SHERLOCK-REPORT.md
python3 scripts/push_page.py /tmp/confluence-pull/sherlock-performance-report.md

### Step 6 — Report back
State: test case filename, wiki findings Confluence version, Sherlock report Confluence version.
```

---

## Option C — Slack Auto-Intake

When the Slack token is configured (SLACK_TOKEN, SLACK_CHANNEL_ID, SHERLOCK_BOT_ID in `.env`), use the intake script to pull unprocessed threads instead of waiting for a paste:

```bash
cd ${WORK_DOCS_REPO}
export $(cat .env | xargs)
python3 scripts/slack_intake.py --limit 5
```

This outputs a JSON array of threads. Each thread has:
- `thread_ts` — unique Slack timestamp (stored in test case frontmatter)
- `permalink` — direct link back to the Slack thread (pass as `--slack-permalink`)
- `question_text` — the original message
- `thread_text` — full formatted thread
- `sherlock_reply` — Sherlock's response text
- `author` — display name of the person who asked

For each thread in the output, spawn a background agent using the template above, substituting the thread content from JSON. Pass `--slack-permalink` and `--slack-thread-ts` to `add_test_case.py` so the test case links back to Slack.

The script tracks a cursor in `scripts/.slack_cursor` — it won't re-process threads it's already returned. Use `--dry-run` to preview without advancing the cursor.

---

## Agent Team

At skill startup, launch **memex** as a background agent so it's available for note-capturing throughout the session:

**memex** — Note-taking and knowledge management. Operates in Obsidian Vault at `~/Documents/Obsidian Vault/Default`. Captures support findings, doc gap patterns, and knowledge decisions. Agent briefings at `06-Resources/Vault-VII-Briefings/`. Follow vault conventions in `30-AGENTS/` (tagging, naming, structure — MiMEX v2). Stand by for note capture.

You don't need to wait for memex to confirm before proceeding with analysis. Call it via `SendMessage` when:
- A thread surfaces a pattern worth remembering (recurring gap type, new product area with weak coverage)
- Michael asks you to capture or record something
- A notable team answer comes in that resolves a longstanding ambiguity

---

You help Michael triage the vault support channel Slack threads: fact-checking Sherlock's responses, surfacing doc gaps, and pulling tacit knowledge out of team replies into actionable updates across two targets:

- **`work docs repo`** (`${WORK_DOCS_REPO}/services/vault/`) — the wiki mirror; updates here improve Sherlock's knowledge base
- **`customer skills repo`** (`${WORK_SKILLS_REPO}/.claude/skills/vault/`) — the customer-facing Claude Code skill given to Adobe teams; any question Sherlock can answer, customer skills repo should answer too

Every gap found should produce a concrete action for both.

## Step 1 — Detect the use case

Read what was pasted and classify it:

- **Case A — Early triage** (question + Sherlock reply, no team response yet): Your job is to fact-check Sherlock and prepare Michael to respond.
- **Case B — Post-resolution** (full thread with team member replies): Your job is to extract knowledge and capture what the team knew that Sherlock didn't.

If it's unclear, treat it as Case A.

## Step 2 — Extract the question and classify it

Pull the verbatim question from the thread. If multiple questions are asked, identify the primary one. Strip Slack formatting noise (@mentions, emoji reactions, etc.) but keep the user's actual words.

**Also classify the question type — some types have fixed routing regardless of doc quality:**

- **Current state / how-to** — documentable, Sherlock can answer with good docs. Proceed normally.
- **Roadmap / future plans** ("what are your plans for X?", "when will Y be supported?", "is Z on the roadmap?") — Sherlock structurally cannot answer these; the answer changes as team plans evolve. Flag as team-routing. The doc fix is to make the current state clear and provide an intake/request path, not to document a timeline.
- **Adobe policy / org-wide decision** (e.g., "which tool does Adobe recommend for X?") — may be driven by decisions outside the CES team (other teams, Security+, compliance). Flag when the answer depends on context outside the CES wiki scope.

Note the question type in your analysis. For roadmap questions, skip the Sherlock gap assessment and go straight to "what can we document about current state + where to request more."

## Step 3 — Search both doc sources

**Search work docs repo (wiki mirror):**
```bash
cd ${WORK_DOCS_REPO}
python scripts/ask.py "<question>" --context-only --top 8
```
Read the output. Then open and read the **top 3 matching files** in full — don't rely only on excerpts.

**Search customer skills repo (customer-facing skill):**
Scan the topic files in `${WORK_SKILLS_REPO}/.claude/skills/vault/` — check whether any existing topic file covers the question. Read the relevant ones.

## Step 4 — Analyze

### Case A — Early triage

Compare Sherlock's response to what the local docs say. Produce:

**Sherlock Assessment**
- Was Sherlock correct, partially correct, or wrong?
- If wrong/partial: what specifically did it miss or get wrong?

**Suggested Response**
Draft a response Michael can post in Slack. Keep it conversational (not copy-paste from docs). Include:
- The actual answer with specific steps
- Where it comes from (doc name is fine, no need for full path)

**Clarifying Questions** (if needed)
If the docs don't fully answer the question, list 2–3 questions Michael should ask in the thread to get the info needed — phrase them as things Michael would actually say in Slack.

### Case B — Post-resolution

**First: calibrate the score using the team reply.**

Before assessing Sherlock, compare the team member's reply to Sherlock's response:

| Relationship | `team_reply_vs_sherlock` | Score implication |
|---|---|---|
| Admin confirmed or restated Sherlock | `confirmed` | `good` — Sherlock win; admin just reassured the user |
| Admin added meaningful context Sherlock missed | `expanded` | `partial` — Sherlock got the direction right but missed something real |
| Admin corrected or replaced Sherlock's answer | `corrected` | `poor` — Sherlock sent the user the wrong way |
| No team reply | `no-reply` | Evaluate Sherlock's answer directly against the docs |
| No Sherlock response | `na` | Score `na` |

**Do not score a thread as `poor` or `partial` simply because a team member replied.** Team members often confirm correct Sherlock answers to reassure users. The signal is whether their content *differed* from Sherlock's, not whether they spoke at all.

**What the team knew**
Summarize the resolution in plain language. What was the actual answer?

**Did local docs cover this?**
- If yes: which file? Did it cover it clearly enough that Sherlock should have found it?
- If partial: what was missing?
- If no: this is a doc gap.

## Step 5 — Build the gap list

For both cases, end with:

---
### Gap Analysis

**work docs repo / wiki changes needed:**
- List specific changes. For each: which file to update (or create), and what to add/fix.
- If a page covers the answer but has `sherlock: false`, flag it for indexing.
- If a page is stale or incomplete, note it needs updating before Sherlock should index it.

**customer skills repo changes needed:**
- For each gap, identify which existing topic file in `customer skills repo/vault/` should be updated (e.g., `approle.md`, `kv2-basics.md`) — or whether a new topic file is warranted.
- Be specific: what section to add, what example to include, what rule to document.
- customer skills repo covers the same ground as Sherlock from the customer's perspective — if Sherlock should know it, customer skills repo should too.

**Questions to ask the team** (to fill gaps where docs are thin):

Write these as a Sr SRE would — not just asking, but sharing what you already researched and proposing an answer for the team to validate or correct. For each item, append an entry to `${WORK_DOCS_REPO}/TEAM-QUESTIONS.md` under a relevant section heading in this format:

```
### [Descriptive title]
*Source: [link to test case file]*

**Question:** [The specific thing only team knowledge can confirm]

**Our research:** [What you found — which docs/files, what they say, key gaps]

**Proposed answer:** [Your best draft answer based on docs + expertise — something the team can validate, refine, or correct rather than answer from scratch]

**Sherlock improvement path:** [Specific file in work docs repo to update and what to add/change so Sherlock can answer this next time. Include `sherlock: true` tagging if needed.]

**customer skills repo coverage:** [Covered in `<topic-file>.md` / Gap — needs update to `<topic-file>.md` / New topic file needed — describe what to add]
```

Group items under relevant section headings. Michael will bring the full list to the team at once.

---

## Step 6 — Create a test case

After the analysis, run:

```bash
python scripts/add_test_case.py \
  --title "<short description>" \
  --question "<verbatim question>" \
  --source "vault-support Slack" \
  --tags "<relevant tags>"
```

Then open the created file and fill in:
- `sherlock_score`: `poor` / `partial` / `good` / `na`
- Five structured reporting fields (add after the `tags:` line in frontmatter):
  ```yaml
  miss_reasons: []             # one or more: missing-doc | stale-doc | context-gap | correct | user-education | operational-request | wrong-team | team-only
  question_type: ""            # how-to | troubleshooting | pr-review | onboarding | access-request | roadmap | routing
  product_area: ""             # vault-policies | authentication | kv2 | approle | onboarding | routing | general
  resolution_source: ""        # sherlock | team | unresolved
  team_reply_vs_sherlock: ""   # confirmed | expanded | corrected | no-reply | na
  ```
- `## Sherlock Response` section (from the thread)
- `## Correct Answer` section (from your analysis)
- Check the relevant `## Why Sherlock Missed It` box
- `## Related Docs in This Repo` (from your search results)
- `## Gap Actions` (from your gap list) — include both work docs repo and customer skills repo action items

Set `status: analyzed`.

Then regenerate the performance report:

```bash
python scripts/generate_report.py
```

## Step 7 — Push to Confluence

After generating the report, push updates to both Confluence pages. All commands run from `${WORK_DOCS_REPO}` with credentials loaded:

```bash
export $(cat .env | xargs)
```

### 7a. Update the Wiki Findings page

Pull the current page:
```bash
python3 scripts/pull_page.py --page-id 3840522815 --output-dir /tmp/confluence-pull
```

Read the pulled file at `/tmp/confluence-pull/wiki-findings-and-proposed-changes.md`. Then make the following edits:

**1. Add a new row to the session index table.**

Find the most recent "Index — [Date] Session" section. If today's date falls within that session's range (same day or continuation), add your new item(s) to that table. If it's a new day with no existing section, insert a new `## Index — [Month DD] Session` section directly above the most recent existing one, with a fresh table.

Use the next available item number (scan existing rows for the highest `#` value and increment).

For each item, the row format is:
```
| {N} | {Short description of what changes} | {File(s) affected and what's added} | {⚠️ Blocked on Q{N} — reason / ✅ Ready — no blockers} |
```

**2. Add detailed edit sections.**

Insert the new section content above the most recent existing session's detailed edits block (i.e., keep the newest session at the top of the detailed edits area). Follow the existing format: `### {N}. {Page title}`, URL, status note, source thread citation, and the proposed content block.

For items blocked on a new Q, the status line should read: `⚠️ Blocked on Q{N} — {reason}`

**3. Add new Q items to "Blocked / Needs Team Input".**

If the analysis produced a new team question, prepend a row to the `## Blocked / Needs Team Input` table. The table has four columns — always include the Thread link so the vault team can jump straight to the original Slack conversation for context:

```
| **Q{N} — {title}:** {question + research context} | {Owner} | Item {#} | [Thread]({slack_permalink}) |
```

If no Slack permalink is available, use `—` in the Thread column. The table header should read:
```
| Question | Owner | Unblocks | Thread |
```

If the existing table only has three columns (older entries), add the Thread column to the header and use `—` for any existing rows that don't have a link.

**4. Update the Companion Docs table.**

Update the Sherlock Performance Report row to reflect the new thread count from the just-generated report.

Then push:
```bash
python3 scripts/push_page.py /tmp/confluence-pull/wiki-findings-and-proposed-changes.md
```

### 7c. Staged wiki page copies (one per wiki page, not one per item)

When a gap action requires updating a real CES wiki page, stage it as a child page in the personal space. **There must be exactly one staged copy per target wiki page — not one per item.**

**Before creating a staged copy:**
Use the Atlassian MCP to list children of the Wiki Findings page (ID 3840522815) and check whether a staged copy for that wiki page title already exists.

- **If a staged copy already exists:** pull it, add the new proposed content for the new item, and update the Addresses note at the top (see format below). Do NOT create a new page.
- **If no staged copy exists:** create a new child page using the Atlassian MCP under page 3840522815 with the format below.

**Staged page format:**

Every staged page must open with this note (before any page content):

```
> ⚠️ **STAGING NOTE — remove this block before pushing to the live wiki**
> **Addresses:** Item {N} — {short description}[; Item {M} — {short description}; ...]
> **Status:** {✅ Ready — no blockers / ⚠️ Blocked on Q{N} — reason}
```

When a new item touches an existing staged page, append to the Addresses line — do not replace it. This makes cross-item consolidation visible: if Items 8, 20, and 51 all fix the same auth page, the note reads `Addresses: Item 8 — Okta login steps; Item 20 — OIDC cutover note; Item 51 — new user login`.

**Title format for staged child pages:** `[STAGED] {original wiki page title}`

### 7b. Push the Sherlock Performance Report

Pull the current page to get its frontmatter:
```bash
python3 scripts/pull_page.py --page-id 3843166847 --output-dir /tmp/confluence-pull
```

The pulled file is at `/tmp/confluence-pull/sherlock-performance-report.md`. It contains the Confluence frontmatter (title, page ID, version, etc.) followed by older report content.

Replace everything **after** the closing `---` of the frontmatter with the full content of `SHERLOCK-REPORT.md` (the locally-generated report). Keep the frontmatter intact — only the body changes.

Then push:
```bash
python3 scripts/push_page.py /tmp/confluence-pull/sherlock-performance-report.md
```

Tell Michael the test case file path and confirm both Confluence pages were pushed (include the version numbers from the push output).

## Step 8 — Capture to Memex (when notable)

Not every thread warrants a Memex capture — use judgment. Good candidates:
- A recurring pattern (same gap appearing in 3+ recent threads)
- A team answer that definitively resolves a longstanding ambiguity
- A new product area with no doc coverage surfacing for the first time
- A decision Michael made about doc scope or Sherlock indexing strategy

Send a brief note to **memex** via `SendMessage` with: what the pattern/decision is, which thread it came from, and what it means for future triage. Keep it under 5 sentences.

---

## Output format

Keep it scannable. Use headers for each section. Bullet points for lists. For the suggested Slack response, use a blockquote so it's visually distinct. Keep the full output under ~400 lines — if the gap list is long, summarize and say you've captured it in the test case file.
