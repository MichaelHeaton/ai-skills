---
name: feedback_reload
description: "⌘R reload shortcut only works in the Claude Code desktop app, not VS Code"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 2aba23b6-5060-4073-bf82-2b5ac8991ef3
---

⌘R works in the desktop app and in iTerm (where it starts a fresh CLI session). It does not work in the VS Code extension.

**Why:** In iTerm, ⌘R resets the terminal session, which starts a new Claude Code process and reloads skills. VS Code intercepts or ignores it for Claude Code purposes.

**How to apply:** When reminding the user to reload after skill changes: ⌘R works in desktop app and iTerm. VS Code users must start a new chat — no known reload shortcut exists for the extension.
