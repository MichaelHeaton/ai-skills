---

name: pr-slack
description: "Generate a TLDR-first Slack message for a Vault team PR review request. Invoke after creating a GitHub PR in any Adobe vault repo. Triggers on: /pr-slack, 'slack message for PR', 'draft PR notification', 'send to vault admins'."
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


# PR Slack Notifier

Generate a ready-to-paste Slack message to send to the Vault Admins team after creating a PR.

## Input

The skill accepts an optional PR number or URL as an argument. If not provided, detect the most recently created PR on the current branch:

```bash
gh pr view --json number,title,url,body,headRefName
```

## Steps

### 1 — Gather PR details

Read the PR:
- **Title** — the PR title
- **URL** — full GitHub URL
- **Body** — PR description (look for Summary bullets and any noted impact)
- **Branch name** — extract the Jira ticket key if present (e.g. `feat/CESSS-13821-...` → `CESSS-13821`)

### 2 — Extract the TLDR

From the PR body, derive a single sentence TLDR. Rules:
- Lead with **what changes** and **why it matters** (not what files changed)
- Keep it under 20 words
- If the PR body has a `## Summary` section, use its first bullet as the basis
- If the body is empty, derive from the PR title

### 3 — Build the Jira URL

If a ticket key was found in the branch name or PR body, construct the full URL:
`https://jira.corp.adobe.com/browse/{TICKET_KEY}`

If no ticket key is found, omit the Jira line entirely — do not guess or leave a placeholder.

### 4 — Format the Slack message

Output the message inside a code block so Michael can copy it cleanly.

Format:

```
Hey team — PR ready for review:

*{REPO_NAME} #{PR_NUMBER}* — {PR_TITLE}
{PR_URL}

*TLDR:* {ONE_SENTENCE_SUMMARY}

Jira: {FULL_JIRA_URL}
```

Rules:
- Always include the full Jira URL, never just the ticket key
- TLDR line comes before the Jira line
- Repo name should be the short name (e.g. `vault_infra`, not the full org path)
- Keep the whole message under 6 lines
- Do not add emoji unless Michael asks

### 5 — Output

Print the formatted message in a fenced code block so it's easy to copy. Then confirm which PR was used (number + title) in a single line below the block.
