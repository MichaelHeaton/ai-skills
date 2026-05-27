---
name: user-environment
description: "Claude Code usage environment — primarily terminal CLI, VS Code extension installed but not yet used"
metadata: 
  node_type: memory
  type: user
  originSessionId: 2aba23b6-5060-4073-bf82-2b5ac8991ef3
---

The user runs Claude Code primarily in the terminal (CLI), often in iTerm. The VS Code extension may be installed but is not the default workflow yet.

**Why:** Affects which reload shortcuts apply and how to frame environment-specific advice.

**How to apply:** Default to CLI/terminal assumptions. When giving VS Code extension advice, flag it as untested if the user has not adopted that workflow.
