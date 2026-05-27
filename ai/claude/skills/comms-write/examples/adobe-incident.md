# Adobe / CES — Incident Report

Used after a customer-impacting incident or significant operational event on a CES service (Vault, Teleport, etc.).

**Audience:** CES leadership, affected teams, on-call rotation  
**Tone:** Factual, no blame, focused on what happened and what changes as a result

## What to gather

- **Incident summary**: What broke and for how long?
- **Impact**: Which teams or services were affected? How many users/systems?
- **Timeline**: When was it detected, triaged, resolved? (approximate times OK)
- **Root cause**: What actually caused it?
- **Immediate fix**: What stopped the bleeding?
- **Follow-up actions**: What changes prevent recurrence? (link Jira tickets if they exist)
- **Jira ticket**: work project issue number if one exists

## Format

```
**Incident Report — [Service]: [Short Title]**
**Date:** [YYYY-MM-DD]  **Severity:** [SEV1 / SEV2 / SEV3]  **Duration:** [X hours Y minutes]

## Summary
[2–3 sentences: what happened, who was affected, current status]

## Timeline
- [HH:MM] — [Event]
- [HH:MM] — [Event]
- [HH:MM] — Resolved

## Root Cause
[What caused it — be specific, not "human error" or "misconfiguration"]

## Impact
- [Affected service/team]
- [Scope: N users, N namespaces, N services, etc.]

## Resolution
[What was done to fix it]

## Action Items
| Action | Owner | Jira | Target |
|---|---|---|---|
| [What will change] | [Name] | [WORK-XXXX] | [Date] |
```

## Guidance

- Write in past tense — the incident is over
- Timeline uses 24h times in PT unless the audience is global, then use UTC
- Root cause should be one or two specific sentences — avoid vague language
- Action items must have an owner and a target date — open-ended actions don't get done
- For SEV1/SEV2: share in the vault support channel and tag affected teams; for SEV3: Jira + 3P mention is enough
