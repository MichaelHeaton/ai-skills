---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: human
---

# CRM Person note template

Use when creating a new `People/<LastName-FirstName>.md` vault note.

```markdown
---
type: person
name: <Full Name>
role: <title or role>
org: <company or team>
tags: [crm, people]
---

# <Full Name>

**Role:** <title>
**Org:** <company>
**Contact:** <email or Slack handle>

## Background

<brief bio or how you know them>

## Contract & Comp

| Date | Type | Terms | Status |
| ---- | ---- | ----- | ------ |
| <YYYY-MM-DD> | <type> | <summary> | <In Review / Active / Closed> |

## Notes

## GitHub Issues

## Related
```
