---
name: project_github_labels
description: GitHub labeling convention — dual-label overlapping types for bot compatibility + taxonomy
metadata: 
  node_type: memory
  type: project
  originSessionId: d4b24898-c21c-4c80-b90e-78485b9393bc
---

When a label type has both a GitHub default and a `type/` custom version, apply **both** labels to the issue.

- `bug` + `type/bug`
- `enhancement` + `type/enhancement`

**Why:** Bots and integrations use GitHub's default labels. The `type/` prefix labels maintain a consistent filterable taxonomy for manual use. Keeping both preserves compatibility now while the integration story is being built out.

**How to apply:** Any skill or workflow that creates issues (issue-create, etc.) should apply both labels when the type maps to a GitHub default. Don't pick one — use both.
