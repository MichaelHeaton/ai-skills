---
version: 1.0.0
last_updated: 2026-06-10
---

# Slack Auto-Intake

When the Slack token is configured (`SLACK_TOKEN`, `SLACK_CHANNEL_ID`, `SUPPORT_BOT_ID` in `.env`), use the intake script to pull unprocessed threads instead of waiting for a paste:

```bash
cd "${WORK_DOCS}"   # repos.work_docs from local.json
export $(cat .env | xargs)
python3 scripts/slack_intake.py --limit 5
```

This outputs a JSON array of threads. Each thread has:

- `thread_ts` — unique Slack timestamp (stored in test case frontmatter)
- `permalink` — direct link back to the Slack thread (pass as `--slack-permalink`)
- `question_text` — the original message
- `thread_text` — full formatted thread
- `sherlock_reply` — the support bot's response text
- `author` — display name of the person who asked

For each thread in the output, spawn a background agent using the template in `background-agent-template.md`, substituting the thread content from JSON. Pass `--slack-permalink` and `--slack-thread-ts` to `add_test_case.py` so the test case links back to Slack.

The script tracks a cursor in `scripts/.slack_cursor` — it won't re-process threads it's already returned. Use `--dry-run` to preview without advancing the cursor.
