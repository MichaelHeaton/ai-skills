---
name: feedback-commits
description: "Don't commit until the user explicitly asks — they review changes via VS Code's green Explorer indicators before committing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2410045b-33d6-4d61-a79f-c9b8e52b856a
---

Wait for explicit "commit" instruction before running git commit.

**Why:** VS Code shows uncommitted changes in green in the Explorer panel. The user uses this as a visual review mechanism — committing too early removes the signal before review.

**How to apply:** Make changes, confirm what was done, then stop. Do not commit unless the user says to.
