---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: skill-create
description: Create a new Claude Code extensibility artifact — skill, subagent, hook, or MCP server — from scratch using a guided interview. Handles the full lifecycle: capturing intent, selecting the right artifact type, naming, writing the config/SKILL.md, testing, iterating, and saving to the repo. Use this whenever the user wants to build or capture a workflow, or says "make a skill for X", "turn this into a skill", "new skill", "make a subagent for X", "create a hook for X", "add an MCP server", "set up MCP for X", "adapt this into a skill", "make our own version of", "build a skill based on", "port this skill", "create a version of [X skill]", or "automate X with a hook".
compatibility: Requires git. Deploy skills with `make install-system` in ai-skills (copy-only; see principles/deployment.md).
---





# Skill Creator

Your job is to guide the user from a rough idea to a working, well-crafted Claude Code extensibility artifact. The process is:

0. Select the artifact type
1. Capture intent
2. Interview and research
3. Name the artifact
4. Write the config / SKILL.md
5. Create the file(s)
6. Test it
7. Iterate until the user is satisfied

Meet the user where they are. If they have a half-formed idea, help them shape it. If they walk in with a draft, skip to testing. If they say "just vibe with me and skip the formalities", do that.

---

## 0. Select the Artifact Type

Before anything else, determine which of the four Claude Code extensibility types fits the use case. If the user's request makes it obvious (e.g. "create a hook for when a file is saved"), confirm and proceed. If it's ambiguous, explain the options and ask.

| Type | What it is | Best for |
|------|-----------|----------|
| **Skill** | SKILL.md loaded on demand; gives Claude task-specific expertise | Repeatable workflows, specialist knowledge, guided processes |
| **Subagent** | Isolated execution context; Claude delegates a bounded task to it | Long-running or risky work that should be isolated from the main session |
| **Hook** | Shell command triggered by a Claude Code event (tool call, session start/stop, etc.) | Automation that should run automatically without Claude deciding to do it |
| **MCP server** | External process exposing tools via the MCP protocol | Integrating third-party APIs, databases, or persistent services |

**Key tradeoffs:**

- **Skill vs. subagent** — Use a skill when Claude needs expertise loaded into context. Use a subagent when the work is long, potentially destructive, or benefits from a clean slate (no prior conversation context leaking in).
- **Hook vs. skill** — Use a hook for things that must happen automatically (e.g. run linter on every file save). Use a skill for things the user consciously invokes.
- **MCP vs. hook** — MCP exposes tools Claude can call. Hooks run shell commands in response to events. MCP is right when Claude needs to query or act on an external system mid-conversation; hooks are right for fire-and-forget side effects.

Once the type is confirmed, follow the type-specific guidance below, then continue with the shared steps (Interview → Name → Write → Create → Test → Iterate).

### Type-specific guidance

#### Skill
- Placement: `ai/claude/skills/{name}/SKILL.md` (global) or `<repo>/.claude/skills/{name}/SKILL.md` (project-scoped)
- Required frontmatter fields: `version`, `principles_version`, `last_updated`, `updated_by`, `name`, `description`
- The `description` field is the primary trigger — write it to answer "what does this do?" and "when should Claude use it?"
- Deploy: `make install-system` in ai-skills copies to `~/.claude/skills/`
- **Reload required after any SKILL.md change** — new conversation or ⌘R

#### Subagent
- Placement: `ai/claude/subagents/{name}.md` (global) or `<repo>/.claude/agents/{name}.md` (project-scoped)
- Required frontmatter fields: `name`, `description`, `model` (optional — defaults to current), `tools` (list of tools the subagent may use)
- The `description` tells Claude when to delegate to this subagent — same principle as skill descriptions
- Keep the subagent's tool list minimal: only what it needs for its bounded task
- See `references/sub-agent-pattern.md` in skill-review for patterns

#### Hook
- Placement: configured in `.claude/settings.json` under `hooks`
- Structure: `{ "event": "<EventName>", "hooks": [{ "type": "command", "command": "<shell cmd>" }] }`
- Supported events: `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SubagentStop`
- Use `update-config` skill to add hooks to the right settings file (global vs. project)
- Commands run with the repo root as CWD; non-zero exit code blocks the tool call (PreToolUse only)
- Hook commands should be fast (<2s) and idempotent

#### MCP server
- Placement: configured in `.claude/settings.json` (or `~/.claude/settings.json` for global) under `mcpServers`
- Structure: `{ "mcpServers": { "<name>": { "command": "<cmd>", "args": [...], "env": {...} } } }`
- For remote MCP: use `"type": "sse"` or `"type": "http"` with a `"url"` field
- Use `update-config` skill to add the server to the right settings file
- After adding, Claude Code must be restarted to pick up new MCP servers
- Verify the server is live: check `MCP Servers` in the Claude Code status bar

---

## 1. Capture Intent

Start by understanding what the user wants. If the current conversation already contains a workflow (tools used, sequence of steps, corrections made), extract answers from it first and ask the user to confirm rather than starting from scratch.

Answer these before moving forward:

- What should this skill enable Claude to do?
- When should this skill trigger? What would a user actually type to kick it off? (concrete phrases, not abstract descriptions)
- What's the expected output — a file, a set of actions, a conversation, something else?
- Does it need to interact with external tools, files, or APIs?

---

## 2. Interview and Research

Before writing anything, dig into edge cases and specifics. Good questions to explore:

- What does success look like? What would a bad output look like?
- What are the 2–3 most common things that could go wrong or be misunderstood?
- Are there existing skills this overlaps with? (Check `~/.claude/skills/` for names)
- Does the skill need bundled scripts, reference docs, or assets?

Check available MCP tools — if any are relevant to the skill's domain, note them for the `compatibility` field.

Don't move to writing until you have enough to make real decisions, not just fill in a template.

---

## 3. Name the Skill

Read `references/conventions.md` for the full naming rules and optional domain-prefix guidance. Key points:

- Format: `{domain}-{verb}` (preferred) or `{domain}-{noun}`; cross-cutting skills may omit a domain prefix (`git-ops`, `grill-me`)
- Lowercase letters and hyphens only, 1–64 characters, no leading/trailing/consecutive hyphens
- Must match the directory name exactly
- Add a `{context}-` prefix only when the skill is useless outside one scope; do not invent employer-specific prefix tables in public skills

Propose a name with a one-line explanation of the domain choice. If the user has a preference, use it — but flag if it violates the convention.

---

## 4. Write SKILL.md

Use this structure:

```
---
version: 1.0.0
principles_version: 1.0.0
last_updated: YYYY-MM-DD
updated_by: human
name: skill-name
description: [see below]
compatibility: [only if needed]
---

# Skill Title

[Brief orientation]

## Sections as needed
```

### Writing the description

The description is the primary trigger mechanism — Claude decides whether to activate a skill almost entirely based on it. Write it to answer two questions:

1. What does this skill do?
2. When should Claude use it? (specific user phrases, contexts, situations)

Lean slightly pushy: Claude tends to undertrigger skills, so err toward listing more situations where the skill applies rather than fewer. Include natural-language trigger phrases the user would actually type.

Max 1024 characters.

### Writing the body

- Keep SKILL.md under 500 lines; move detail into `references/` if needed
- Imperative form: "Do X", not "You should X"
- Explain the *why* behind non-obvious steps — don't just list instructions
- Skip comments that restate what the code does
- Avoid ALWAYS/NEVER in all-caps; instead explain the reasoning so it generalises

### Output formatting

Global formatting rules (ADHD-friendly: chunked output, bold key terms, ✓/✗/⚠️ status symbols, lead with the point) are in `~/.claude/CLAUDE.md` and apply automatically — do not repeat them in the skill body.

If the skill produces complex structured output (reports, audits, multi-section results), reference `references/formatting.md` in the skill's own `references/` directory for patterns specific to that output type.

---

## 5. Create the File(s)

Once the user approves the draft:

> **Supporting scripts or tools discovered during skill development?** Create a ticket for that work via `issue-create` before starting — keeps implementation traceable even when the work is done and closed in the same session.

**For skills:**

1. Create the directory: `mkdir -p ai/claude/skills/{name}`
2. Write `SKILL.md` there (and `references/conventions.md` copy if this is a meta skill).
3. Create `scripts/`, `references/`, or `assets/` only if needed.
4. Run `make bootstrap-version` and `make manifest-update` from the ai-skills repo root.
5. Deploy: `make install-system` (copies to `~/.claude/skills/`).
6. Update `README.md` / `AGENTS.md` if the skill changes documented workflows.
7. Branch + PR in ai-skills — do not commit to `main` directly.
8. **Reload required** — remind the user: new conversation or ⌘R.

**For subagents:**

1. Create the file: `ai/claude/subagents/{name}.md` (or `<repo>/.claude/agents/{name}.md` for project-scoped).
2. Write the frontmatter (`name`, `description`, `tools`) and the body (the subagent's instructions).
3. Deploy: `make install-system` or copy manually to `~/.claude/subagents/`.
4. Branch + PR in ai-skills — do not commit to `main` directly.
5. **Reload required** — new conversation or ⌘R.

**For hooks:**

1. Use the `update-config` skill to add the hook to the correct `settings.json` (global or project).
2. The hook entry goes under `hooks` in `settings.json` — see Step 0 for the structure.
3. No deploy step needed — hooks take effect immediately in the current session.
4. If the hook command is non-trivial, write it as a script in `~/.claude/scripts/` and reference it.

**For MCP servers:**

1. Use the `update-config` skill to add the server under `mcpServers` in the correct `settings.json`.
2. If the server requires local installation, run it now (e.g. `npm install -g @example/mcp-server`).
3. **Restart required** — Claude Code must be fully restarted to pick up new MCP servers.
4. Verify: confirm the server appears in the Claude Code status bar after restart.

---

## 6. Test the Artifact

**Skills and subagents:** Come up with 2–3 realistic test prompts — the kind of thing a real user would actually type. Share them with the user before running: "Here are the prompts I'd like to test. Do these look right?" For each, follow the skill's own instructions to complete the task, then show the output. Be honest about what worked and what felt off.

Good test prompts are:
- Specific and concrete (include file names, context, personal details)
- Varied in phrasing (formal, casual, abbreviated)
- Focused on edge cases, not just the obvious happy path

**Hooks:** Test by triggering the event the hook listens on (e.g. run a tool call for `PreToolUse`, end the session for `Stop`). Confirm the hook command ran and produced the expected side effect. Check exit codes — a non-zero exit from a `PreToolUse` hook blocks the tool.

**MCP servers:** After restart, confirm the server appears in the status bar. Run a tool call that exercises the server and verify the response. Check for auth errors or missing env vars early — they fail silently until first use.

---

## 7. Iterate

After the user reviews the test outputs, improve the skill based on their feedback.

When revising:

- **Generalise, don't overfit.** The goal is a skill that works for a million different prompts, not just the ones you tested. Resist adding rigid rules for specific cases; instead, explain the underlying principle.
- **Keep the prompt lean.** Remove instructions that aren't pulling their weight. If the skill is making Claude do unproductive things, cut the part causing it.
- **Explain the why.** Today's models respond better to understanding than to mandates. If you find yourself writing ALWAYS or adding rigid structure, step back and ask if you can explain the reasoning instead.

Repeat test → review → revise until the user is satisfied.

---

## 8. Description Optimization (optional)

After the skill is working well, offer to sharpen the description for better triggering. Walk through this with the user:

1. Write 8–10 "should trigger" prompts — varied phrasings, some casual, some edge cases
2. Write 8–10 "should not trigger" prompts — near-misses that share keywords but need something else
3. Review the set with the user and prune bad examples
4. Rewrite the description based on patterns in the edge cases
5. Update the frontmatter with the new description

The key signal: if a prompt is ambiguous about whether the skill applies, it's a useful test case. If it's obviously in or obviously out, it teaches you nothing.
