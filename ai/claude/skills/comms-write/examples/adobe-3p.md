# Adobe / CES — 3P Update

3P = Progress, Plans, Problems. Written weekly, usually for the Vault Admin team within CES.

**Audience:** CES leadership, adjacent teams, management chain  
**Length:** Readable in 30–60 seconds  
**Tone:** Factual, concise, no jargon that CES leadership wouldn't know

## What to gather

Ask the user for or pull from available sources (work Jira project, vault support channel, recent PRs):

- **Progress**: What shipped or was completed this week? (merged PRs, resolved incidents, closed Jira tickets, completed migrations)
- **Plans**: What is the team focused on next week? (top 2–3 priorities)
- **Problems**: What is slowing things down? (blockers, understaffing, pending approvals, stuck incidents)

If Jira is available, search the work project from local config. If Slack is available, check the vault support channel. Ask the user to fill gaps.

## Format

```
**[Team Name] — [Date Range]**

**Progress**
- [Concrete accomplishment — what shipped or resolved]
- [Another accomplishment]

**Plans**
- [Top priority for next week]
- [Second priority]

**Problems**
- [Blocker or issue slowing the team down] — [who owns resolution or what's needed]
```

## Guidance

- Each bullet should be one sentence max
- Progress bullets lead with the outcome, not the activity ("Merged auto-unseal failover runbook" not "Worked on runbook")
- Problems must include what's needed to resolve them — a blocker with no owner is useless
- If there are no problems, write "None this week" — don't omit the section
- Keep the team name consistent with what the user calls it in other updates
