---
version: 1.2.1
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: vault-support
description: "Analyze vault support content — Slack threads, Jira tickets, direct research questions, or documentation gap sessions — to fact-check the team bot, identify documentation gaps, and generate knowledge-extraction questions. Use when the user pastes a Slack thread, references a vault ticket, asks a vault behavior/config question directly, or wants to identify what's missing in the wiki. Triggers on: vault questions, bot responses, AppRole, policy PRs, KV2, seal, onboarding pasted from Slack, vault ticket, vault runbook, vault restore procedure, vault behavior, researching vault, how does vault handle, look at this vault ticket, wiki gaps, documentation backlog, doc backlog, what's missing in the wiki, identify documentation gaps, audit our docs, build a doc backlog, find wiki gaps, what are we missing in the docs."
---

# Vault Support Analyzer

## Scope

Covers **server/policy-side Vault administration**: KV2, AppRole, Vault Agent config, MCP setup, secret rotation, policy compliance, and wiki/doc-gap analysis for the support bot.

Does **not** cover **client-tooling or auth-method migration issues** — e.g. migrating a local CLI wrapper from one auth backend to another (Okta → OIDC). Those are diagnosed by reading the relevant client tool's own repo directly, not by expecting this skill to be the diagnostic path.

## Configuration (required)

Read `~/.config/ai-skills/local.json` before any steps:

| Key | Use |
| --- | --- |
| `repos.work_docs` | Clone path for wiki mirror + scripts (`ask.py`, `add_test_case.py`, Confluence push) |
| `repos.work_skills` | Customer-facing vault skill topic files |
| `slack.vault_support_channel` | Support Slack channel name (private) |

Export `WORK_DOCS` / `WORK_SKILLS` from those paths in shell steps. Confluence page IDs live in the work docs repo `.env` — not in this public skill.

## Processing Mode

**Default (foreground):** Run all steps inline. Best for Case A triage (needs a Slack response drafted), ambiguous threads, or when the user wants to discuss findings before pushing.

**Background mode:** When the user adds `--bg`, says "background", or says "run in background" after pasting a thread — confirm receipt and immediately spawn a background agent to handle Steps 3–8. Return control to the user right away.

Use background mode for Case B threads where the team already resolved it and no discussion is needed before logging.

**How to spawn the background agent:** See [references/background-agent-template.md](references/background-agent-template.md) for the full self-contained prompt to pass to the Agent tool with `run_in_background=True`.

---

## Option C — Slack Auto-Intake

See [references/slack-auto-intake.md](references/slack-auto-intake.md) for the intake script details and JSON output format.

---

## Agent Team

Launch **memex** as a background agent at skill startup (personal KB at comms_write.memex_repo_path — follow that vault AGENTS.md). Don't wait for it before proceeding.

Call it via `SendMessage` for: recurring gap patterns, user capture requests, or team answers that resolve longstanding ambiguities.

---

Triage vault support Slack threads: fact-check the support bot, surface doc gaps, extract team knowledge. Every gap produces a concrete action for both:

- **`repos.work_docs`** — wiki mirror; improves the support bot's knowledge base
- **`repos.work_skills`** — customer-facing Claude Code skill tree

## Step 1 — Detect the use case

Read what was provided and classify it:

- **Case D — Gap analysis / doc backlog** (user asks "what's missing in the wiki", "find doc gaps", "build a doc backlog", "audit our docs", or similar — no pasted source): Run a broad doc-search across the wiki mirror, identify uncovered or thin topic areas, and output a structured gap list (see Case D section). This is the right entry point for planning sessions and documentation sprints — the output feeds directly into issue-create.
- **Case A — Early triage** (Slack thread: question + bot reply, no team response yet): Fact-check the support bot and prepare the user to respond.
- **Case B — Post-resolution** (Slack thread: full thread with team member replies): Extract knowledge and capture what the team knew that the support bot didn't.
- **Case C — Jira ticket** (user provides a Jira ticket ID/URL or asks to look at a vault ticket): Fetch ticket via MCP, extract the question or work context, then run the analysis flow (Steps 3+) treating the ticket description as the source.
- **Case D (single question) — Direct research** (user asks a specific vault behavior/config question directly with no pasted source): Skip the bot-comparison steps; run doc-search and gap analysis, then optionally log a test case with `source: "direct research"`.

If unclear, ask: "Is this a Slack thread, a Jira ticket, a specific research question, or a broader doc gap audit?"

## Step 2 — Extract the question and classify it

Pull the verbatim question from the thread. If multiple questions are asked, identify the primary one. Strip Slack formatting noise (@mentions, emoji reactions, etc.) but keep the user's actual words.

**Also classify the question type — some types have fixed routing regardless of doc quality:**

- **Current state / how-to** — documentable, the support bot can answer with good docs. Proceed normally.
- **Roadmap / future plans** ("what are your plans for X?", "when will Y be supported?", "is Z on the roadmap?") — the support bot structurally cannot answer these; the answer changes as team plans evolve. Flag as team-routing. The doc fix is to make the current state clear and provide an intake/request path, not to document a timeline.
- **Employer policy / org-wide decision** (e.g., "which tool the employer recommends for X?") — may be driven by decisions outside the team wiki scope (other teams, Security+, compliance). Flag when the answer depends on context outside the team wiki scope.

Note the question type in your analysis. For roadmap questions, skip the the support bot gap assessment and go straight to "what can we document about current state + where to request more."

## Step 3 — Search both doc sources

**Search work docs repo (wiki mirror):**

```bash
cd "${WORK_DOCS}"   # repos.work_docs from local.json
python scripts/ask.py "<question>" --context-only --top 8
```

Read the output. Then open and read the **top 3 matching files** in full — don't rely only on excerpts.

**Search work customer skills repo (customer-facing skill):**
Scan topic files under `repos.work_skills` (vault skill directory) — check whether any existing topic file covers the question.

## Step 4 — Analyze

### Case A — Early triage

Compare the support bot's response to what the local docs say. Produce:

**the support bot Assessment**

- Was the support bot correct, partially correct, or wrong?
- If wrong/partial: what specifically did it miss or get wrong?

**Suggested Response**
Draft a response the user can post in Slack. Keep it conversational (not copy-paste from docs). Include:

- The actual answer with specific steps
- Where it comes from (doc name is fine, no need for full path)

**Clarifying Questions** (if needed)
If the docs don't fully answer the question, list 2–3 questions the user should ask in the thread — phrase them as things they would actually say in Slack.

### Case B — Post-resolution

Compare the team member's reply to the support bot's response:

| Relationship | `team_reply_vs_sherlock` | Score implication |
| --- | --- | --- |
| Admin confirmed or restated the support bot | `confirmed` | `good` — the support bot win; admin just reassured the user |
| Admin added meaningful context the support bot missed | `expanded` | `partial` — the support bot got the direction right but missed something real |
| Admin corrected or replaced the support bot's answer | `corrected` | `poor` — the support bot sent the user the wrong way |
| No team reply | `no-reply` | Evaluate the support bot's answer directly against the docs |
| No the support bot response | `na` | Score `na` |

**Do not score a thread as `poor` or `partial` simply because a team member replied.** Team members often confirm correct the support bot answers to reassure users. The signal is whether their content *differed* from the support bot's, not whether they spoke at all.

**What the team knew**
Summarize the resolution in plain language. What was the actual answer?

**Did local docs cover this?**

- If yes: which file? Did it cover it clearly enough that the support bot should have found it?
- If partial: what was missing?
- If no: this is a doc gap.

### Case C — Jira ticket intake

**Fetch the ticket:**

Use the Atlassian MCP `jira_get_issue` with the ticket key. Read `jira.*` from `~/.config/ai-skills/local.json` for the project key if needed.

Extract:

- The primary question or work context from the ticket description/title
- Any related comments that contain team knowledge or resolution notes
- Linked tickets or epics that provide context

Treat the extracted question as the verbatim question (Step 2 equivalent). Skip bot-comparison scoring (`sherlock_score: na`, `team_reply_vs_sherlock: na`). Proceed directly to Step 3 (doc search) and onwards.

When creating a test case (Step 6), use `source: "vault ticket"` and set the ticket key in a `jira_ref` field.

### Case D — Direct research (single question)

**No source artifact.** The user is asking a specific vault behavior or config question directly.

Extract the question from the user's message. Skip bot-comparison scoring (`sherlock_score: na`, `team_reply_vs_sherlock: na`). Proceed to Step 3 (doc search) and onwards.

When creating a test case (Step 6), use `source: "direct research"`. The "Correct Answer" section should contain your research findings rather than a team answer.

### Case D — Gap analysis / doc backlog (broad audit)

**No source artifact, no specific question.** The user wants to find what's missing or thin in the wiki.

1. **Scan the wiki mirror** — list all topic files in `${WORK_DOCS}`, group by section/area
2. **Identify gaps** — topics with no file, files under 200 lines, files with `sherlock: false` on most pages, areas with no recent updates
3. **Cross-reference with support volume** — if `TEAM-QUESTIONS.md` exists, check for recurring questions with no corresponding doc
4. **Output a structured gap list:**

```
## Doc Gap Audit — <date>

### Missing topics (no file exists)
- <topic> — <why it matters / signals it's needed>

### Thin coverage (file exists but needs work)
- <file> — <what's missing>

### Not indexed for the support bot (sherlock: false)
- <file> — <whether it's ready to index or needs cleanup first>
```

1. **Offer to create issues** — after presenting the list, ask: "Want me to create GitHub Issues for any of these gaps?" The list feeds directly into `issue-create`.

## Step 5 — Build the gap list

For all cases, end with:

---

### Gap Analysis

**work docs repo / wiki changes needed:**

- List specific changes. For each: which file to update (or create), and what to add/fix.
- If a page covers the answer but has `sherlock: false`, flag it for indexing.
- If a page is stale or incomplete, note it needs updating before the support bot should index it.

**work customer skills repo changes needed:**

- For each gap, identify which existing topic file in `work customer skills repo/vault/` should be updated (e.g., `approle.md`, `kv2-basics.md`) — or whether a new topic file is warranted.
- Be specific: what section to add, what example to include, what rule to document.
- work customer skills repo covers the same ground as the support bot from the customer's perspective — if the support bot should know it, work customer skills repo should too.

**Questions to ask the team** (to fill gaps where docs are thin):

For each item, append an entry to `TEAM-QUESTIONS.md` under a relevant section heading. Follow the format in [references/gap-analysis.md](references/gap-analysis.md) — write as a Sr SRE: share your research and propose an answer the team can validate.

---

## Step 6 — Create a test case

After the analysis, run:

```bash
python scripts/add_test_case.py \
  --title "<short description>" \
  --question "<verbatim question>" \
  --source "<vault support Slack | vault ticket | direct research>" \
  --tags "<relevant tags>"
```

Then open the created file and fill in:

- `sherlock_score`: `poor` / `partial` / `good` / `na`
- Five structured reporting fields after `tags:` — see [references/test-case-fields.md](references/test-case-fields.md)

- `## the support bot Response` section (from the thread)
- `## Correct Answer` section (from your analysis)
- Check the relevant `## Why the support bot Missed It` box
- `## Related Docs in This Repo` (from your search results)
- `## Gap Actions` (from your gap list) — include both work docs repo and work customer skills repo action items

Set `status: analyzed`.

Then regenerate the performance report:

```bash
python scripts/generate_report.py
```

## Step 7 — Push to Confluence

See [references/confluence-push.md](references/confluence-push.md) for full instructions (wiki findings page, staged copies, support bot report). Confirm both pages were pushed with version numbers.

## Step 8 — Capture to Memex (when notable)

Good candidates: recurring gap pattern (3+ threads), team answer that resolves a longstanding ambiguity, new product area with no coverage, a doc scope decision. Send a brief note to **memex** via `SendMessage` (≤5 sentences: what, which thread, implications for future triage).

## Output format

Scannable headers. Bullets for lists. Blockquote for the suggested Slack response. Summarize long gap lists — details live in the test case file.
