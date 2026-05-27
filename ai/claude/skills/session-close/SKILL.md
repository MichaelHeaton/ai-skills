---

name: session-close
description: Safely close out a Claude Code session across all active repos. Checks repos in the active VS Code workspace (falls back to ~/Projects if no workspace file found) for uncommitted changes, unmerged worktree branches, and stale worktree dirs — then guides through commit, push, PR, and merge for each. Also updates any in-progress tickets touched this session and produces a session-end summary so the next session starts with full context. Trigger on: "wrap up", "close out this session", "end of session", "I'm done for today", "session close", "before I close", "session cleanup", "closing up", "wrap this up", "done for the day", "ending this chat", "finishing up", or any request to clean up repos or close out work before ending a Claude chat.
compatibility: Requires gh CLI, glab CLI, git. Atlassian MCP needed only if Jira tickets were worked on.
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---


Close out this session safely. The goal: nothing stranded in branches, all tickets reflect current state, next session starts with complete context.

## Why this matters

Claude sessions leave work stranded when:
- Vault notes or task index entries live in a worktree branch that never merged — the next session can't read them
- Memex is checked out on a capture/feature branch, not `main` — the next session reads stale context
- Dead worktree dirs accumulate in `.claude/worktrees/` and create confusion
- Tickets stay "in progress" after work is done or paused, giving the next session a wrong picture

---

## Step 1 — Discover repos with open work

```bash
bash ~/.claude/skills/session-close/scripts/discover-repos.sh
```

This scans repos in the active VS Code workspace (detected via `*.code-workspace` file in `$PWD`) and prints only those that need attention. Falls back to `~/Projects/` if no workspace file is found. Parse the output to build a working list.

For each line, extract:
- `REPO` — absolute path
- `BRANCH` — current checkout branch
- `CHANGES` — count of uncommitted files
- `WORKTREES` — count of active extra worktrees
- `AHEAD_BRANCHES` — count of remote branches beyond main/master

**Note on high ahead-branch counts**: Some team repos will always show many remote branches from other contributors — not yours to clean up. Focus on repos where you did work this session.

Ask: "Which of these repos were you working in this session?" If the user says "all" or it's obvious from context, proceed with all flagged repos.

---

Before Steps 2–4, invoke the `git-ops` skill _(personal — ai-skills repo)_ — it covers branching rules, commit format, PR format, and pre-commit checks. The short version: work GitHub and GitLab repos always get a branch + PR; personal KB uses branch + PR like work repos. Full rules in `~/.claude/references/branching.md`.

### SSH port-22 fallback (GitHub + GitLab)

For **all git remote operations** on GitHub or GitLab repos using SSH (push, fetch, pull), use the wrapper script instead of raw `git`. It handles port-22 detection and HTTPS switching without any AI-side logic or token cost:

```bash
bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh <repo-path> <subcommand> [args...]

# Examples:
bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh /path/to/repo push -u origin my-branch
bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh /path/to/repo fetch --prune
```

HTTPS remotes and non-GitHub/GitLab hosts pass through to `git` unchanged. When port 22 is blocked: the initial attempt times out in 15 s, the script probes port 22 to confirm the cause, switches `origin` from SSH to HTTPS, and retries. The HTTPS URL is kept for the rest of the session.

---

## Step 2 — Handle uncommitted changes (per repo)

For each repo with `CHANGES > 0`:

1. Show the diff: `git -C <repo> status --short` and `git -C <repo> diff --stat`
2. Ask: commit these changes, discard them, or leave for next session?
3. If committing: run the standard commit flow (stage relevant files, write message, push)
4. If leaving: note it in the session summary as "pending"

---

## Step 3 — Handle worktrees (per repo)

For each repo with `WORKTREES > 0`:

1. List all worktrees: `git -C <repo> worktree list`
2. For each non-main worktree, check its status:
   ```bash
   git -C <worktree-path> status --short
   git -C <worktree-path> log main..HEAD --oneline 2>/dev/null || \
   git -C <worktree-path> log master..HEAD --oneline 2>/dev/null
   ```
3. For worktrees with committed but unpushed work:
   - Push the branch (use the wrapper for GitLab repos; raw git for others):
     ```bash
     # GitHub or GitLab SSH remotes:
     bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh <worktree-path> push -u origin <branch>
     # HTTPS remotes or other hosts:
     git -C <worktree-path> push -u origin <branch>
     ```
   - Create a PR (use `gh pr create` for GitHub repos, `glab mr create` for GitLab)
4. For worktrees with uncommitted changes: handle via Step 2 flow first, then push + PR
5. For worktrees with no new commits (already merged or empty): skip — handled by prune in Step 5

**Memex-specific check**: After handling worktrees, verify that this session's vault notes and task index entries are reachable from `main`. Run:
```bash
git -C ~/Projects/personal/memex log main..HEAD --oneline 2>/dev/null
```
If notes are on a branch that hasn't merged, flag this prominently — the next session will start blind.

---

## Step 4 — Handle non-main branch checkouts

For each repo where `BRANCH != main` and `BRANCH != master` and `WORKTREES == 0`:

1. Show what's on the branch vs main: `git -C <repo> log main..HEAD --oneline`
2. If it's a feature branch with a PR: confirm the PR exists and is up to date
3. If it's a capture branch (e.g. `captures-2026-05-15`): this is expected for Memex — but verify commits are pushed
4. If the branch should be on main: guide through merge or PR creation

---

## Step 5 — Prune dead worktrees

For each repo that had `WORKTREES > 0`, clean up stale dirs:

```bash
git -C <repo> worktree prune
```

Confirm before running. After pruning, verify: `git -C <repo> worktree list` should show only the main worktree (plus any you intentionally kept open).

---

## Step 6 — Skill hygiene review

Invoke `skill-review` _(personal — ai-skills repo)_ in session-audit mode. It will reflect on the current conversation to find skill friction, missed triggers, and ungapped workflows worth turning into new skills. Findings always become tickets before being worked or deferred.

**Reminder**: ai-skills is a public repo. Ticket content must be scrubbed of Employer-internal hostnames, internal ticket keys used as examples, security details, and anything sensitive. skill-review enforces this — but flag it here so it's visible without reading that skill.

**Before invoking skill-review**, annotate each skill that fired with its source so skill-review routes edits to the correct repo:

```bash
# For each skill name, check global install first, then project repos
ls ~/.claude/skills/<name>/          # present → global: ai-skills
find ~/Projects -maxdepth 4 -path "*/.claude/skills/<name>" -type d 2>/dev/null
# present → project: <repo-name>
```

Build a source-annotated list, e.g.:
```
Skills active this session:
- session-close (global: ai-skills)
- skill-review (global: ai-skills)
- quest-sync (project: minecraft-modpack-cp-verdant)
```

Pass this annotated list to skill-review as part of the SA1 context block so it knows where to send edits.

Say: "Running session-audit mode of skill-review."

Then invoke the `skill-review` skill. It handles everything from here.

---

## Step 7 — Permission-prompt hygiene

Ask: "Want to run a permission-prompt hygiene pass? It scans recent transcripts and adds an allowlist to reduce repetitive approval prompts — takes about a minute."

- If **yes** → invoke the `fewer-permission-prompts` skill _(built-in — Claude Code)_
- If **no** → move on without friction

---

## Step 8 — Lean context audit

Reflect on how context was managed this session. This takes 30 seconds and shapes habits for the next session.

**Exempt from flagging**: Running session-close at the end of a session is expected — do not flag it as "multiple unrelated tasks." Only flag task switching that happened *during* the working session.

Check for any of these patterns (from your own observation of the session):

| Pattern | Flag? |
|---|---|
| Thread grew long on the same task without `/compact` | ⚠️ if thread felt heavy |
| Multiple unrelated tasks handled in one session (excluding session-close) | ⚠️ recommend fresh session next time |
| Wide file scans instead of targeted reads | ⚠️ note for lean-context |
| Raw TF/Ansible/log output loaded without `clog` | ⚠️ remind about log-clip |
| Opus invoked for tasks Sonnet could have handled | ⚠️ note overkill |

Report what you observed (or "context stayed disciplined — no issues"). Add a one-line "Context health" note to the session summary in Step 10.

**Known gap**: This audit only sees the current session. Patterns that repeat across many sessions (but aren't flagged within any single one) are invisible here. No good solution without external logging — accept this limit for now.

---

## Step 9 — Update in-progress tickets

Do not ask the user if they worked on tickets. Instead, find them from the index and the session's git activity.

**Step 9a — Load open tickets from the index**

```bash
grep '"status":"open"' ~/Projects/personal/memex/Raw/_task-index.jsonl \
  | python3 -c "import sys,json; [print(json.loads(l)['system'], json.loads(l)['id'], json.loads(l)['title']) for l in sys.stdin]"
```

**Step 9b — Cross-reference against this session's git work**

For each repo worked in this session, scan recent commit messages, branch names, and PR titles for ticket IDs:

```bash
git -C <repo> log --oneline --since="12 hours ago"
```

Look for patterns like `PROJ-12345`, `PROJ-###`, `#94`, or ticket keywords matching index titles.

**Step 9c — Act on matches**

For each open ticket that matches session activity:
- If work is **done** → transition to Done/Closed or add a closing comment
- If work is **in review** (PR open) → update status to "In Review", add PR link in comment
- If work is **paused** → add a comment with where things stand so the next session picks up cleanly
- If work is **blocked** → add a blocker comment and transition to Blocked

Use `jira_transition_issue` + `jira_add_comment` for Jira, `gh issue comment` + `gh issue edit` for GitHub. Update `status` in `_task-index.jsonl` to reflect the new state.

**If no matches are found**: say "No open tickets matched this session's git activity — skipping ticket updates." Do not ask an open question.

**Why this matters**: Tickets that stay "In Progress" after a session ends give the next session (and teammates) a wrong picture of what's active. The index already has the answer — don't make the user recall it from memory.

---

## Step 10 — Session summary

Produce a brief close-out summary. Structure:

```
## Session Close — [date]

### ✓ Clean
- <repo> — all changes committed and pushed
- <ticket> — closed/transitioned

### → Open PRs (needs review/merge)
- <repo>/<branch> — PR #N: <title>

### ⚠️ Pending (needs attention next session)
- <repo> — <what was left and why>
- <ticket> — <current state>

### Next session context
- Memex is on: [branch] — [merged to main? yes/no]
- Worktrees still active: [list or "none"]

### Context health
- [one line from Step 8 — disciplined / patterns noticed / suggestions for next session]
```

Save this summary to `~/Projects/personal/memex/Outputs/Session/session-close-[date].md` if there's anything non-trivial to carry forward. Delete after the next session picks it up.
