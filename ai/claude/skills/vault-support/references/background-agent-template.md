---
version: 1.0.0
last_updated: 2026-06-10
---

# Background agent template

Use this prompt template when spawning a background agent for Case B threads (already resolved, no discussion needed before logging). The prompt must be fully self-contained — the agent has no session context.

```
You are processing a vault support Slack thread for the vault support triage system.
Working directory: repos.work_docs from ~/.config/ai-skills/local.json

## Thread (verbatim)

{PASTE_FULL_THREAD_HERE}

---

## Your tasks — complete all steps in order:

### Step 1 — Search work docs repo
cd "${WORK_DOCS}"   # repos.work_docs from local.json
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
  --source "vault support Slack" \
  --tags "{TAGS}" \
  {--slack-permalink "{PERMALINK}" if available}

Then open the created file and fill in all sections:
- frontmatter fields (sherlock_score, miss_reasons, question_type, product_area, resolution_source, team_reply_vs_sherlock)
- ## the support bot Response (verbatim from thread)
- ## Correct Answer
- ## Why the support bot Missed It (check the right box)
- ## Related Docs in This Repo
- ## Gap Actions (both work docs repo and work customer skills repo actions)
Set status: analyzed.

### Step 4 — Regenerate report
python3 scripts/generate_report.py

### Step 5 — Push Confluence
export $(cat .env | xargs)
python3 scripts/pull_page.py --page-id <FINDINGS_PAGE_ID> --output-dir /tmp/confluence-pull
# Add row + edit section to wiki-findings-and-proposed-changes.md (see confluence-push.md)
python3 scripts/push_page.py /tmp/confluence-pull/wiki-findings-and-proposed-changes.md
python3 scripts/pull_page.py --page-id <PERF_REPORT_PAGE_ID> --output-dir /tmp/confluence-pull
# Replace body with SHERLOCK-REPORT.md content
python3 scripts/push_page.py /tmp/confluence-pull/sherlock-performance-report.md

### Step 6 — Report back
State: test case filename, wiki findings Confluence version, the support bot report Confluence version.
```
