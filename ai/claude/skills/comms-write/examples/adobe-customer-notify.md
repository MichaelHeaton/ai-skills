# Adobe / CES — Customer Notification

Used when CES needs to notify Adobe teams consuming a service about planned maintenance, breaking changes, incidents, or required actions.

**Audience:** Adobe engineering teams using CES services (Vault, Teleport, CyberArk, etc.)  
**Channel:** vault support channel (from local config) + direct DM to affected team leads if urgent  
**Tone:** Clear, empathetic, action-oriented — customers need to know what to do, not just what happened

## What to gather

- **What is the notification about?** (maintenance, breaking change, incident, required migration, etc.)
- **Which service?** (Vault, Teleport, CyberArk, Emissary, etc.)
- **Who is affected?** (all customers, specific namespaces, specific teams)
- **What action (if any) is required from customers?** What's the deadline?
- **What is the timeline?** (when will it happen, when will it be complete)
- **Who should customers contact with questions?** (Slack channel, Jira queue)

## Format

```
**[SERVICE] — [Short Title]**

Hi teams,

[1–2 sentence summary of what's happening and why it matters to them.]

**What's happening:**
[Clear description of the change or event]

**Who is affected:**
[Specific scope — "all Vault customers in prod", "teams using transit mount", etc.]

**What you need to do:**
[Clear action items with deadlines — or "No action required" if true]
- [ ] [Action 1] — by [date]
- [ ] [Action 2] — by [date]

**Timeline:**
- [Date/time]: [What happens]
- [Date/time]: [What happens]

**Questions?**
Reach out in [#channel] or open a [Jira ticket](link).

— [Name], Vault Admin
```

## Guidance

- Lead with customer impact, not the technical cause
- "No action required" is fine — say it explicitly so customers don't wonder
- If there's a deadline, make it bold and specific (not "soon" or "next week")
- For breaking changes: always include a migration path or link to one
- For maintenance windows: include the blast radius and rollback plan if relevant
- Don't use Adobe internal jargon that customer teams may not know (e.g., don't say "our CI/CD pipeline" — say "the automation that syncs Vault policies")
