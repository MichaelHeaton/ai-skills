---
version: 2.0.0
principles_version: 1.0.0
last_updated: 2026-08-24
updated_by: claude
---

# Gap analysis format

## Team questions format

Write questions as a Sr SRE would — share what you already researched and propose an answer for the team to validate. Include directly in your response to the user (there's no persisted question log — the `ces-documentation` repo that once hosted `TEAM-QUESTIONS.md` was decommissioned 2026-08-24; Confluence is the sole source of truth now and this skill doesn't write to it):

```
### [Descriptive title]
*Source: [Slack permalink or Jira ticket link]*

**Question:** [The specific thing only team knowledge can confirm]

**Our research:** [What you found — which Confluence pages/skill files, what they say, key gaps]

**Proposed answer:** [Your best draft answer based on docs + expertise]

**the support bot improvement path:** [Specific Confluence page to update, or note if it needs to move under the indexed KB subtree (pageId 2523173073) to be visible at all.]

**work customer skills repo coverage:** [Covered in `<topic-file>.md` / Gap — needs update / New topic file needed]
```

Group items under relevant section headings. The user will bring the full list to the team at once.
