---
version: 1.4.2
principles_version: 1.0.0
last_updated: 2026-06-12
updated_by: claude
name: session-close
description: Safely close out a Claude Code session across all active repos. Checks repos in the active VS Code workspace (falls back to ~/Projects if no workspace file found) for uncommitted changes, unmerged worktree branches, and stale worktree dirs — then guides through commit, push, PR, and merge for each. Also updates any in-progress tickets touched this session and produces a session-end summary so the next session starts with full context. Trigger on: "wrap up", "close out this session", "end of session", "I'm done for today", "session close", "before I close", "session cleanup", "closing up", "wrap this up", "done for the day", "ending this chat", "finishing up", or any request to clean up repos or close out work before ending a Claude chat.
compatibility: Requires gh CLI, glab CLI, git. Atlassian MCP needed only if Jira tickets were worked on.
---

Close out this session safely. The goal: nothing stranded in branches, all tickets reflect current state, next session starts with complete context.

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

**SSH port-22 fallback**: For all GitHub/GitLab SSH remote operations, use `scripts/git-ssh-fallback.sh <repo-path> <subcommand> [args...]` instead of raw `git`. It auto-detects port-22 blocks, switches to HTTPS, and retries transparently.

**GH auth pre-flight (personal repos):** Before processing any GitHub.com repo, verify the active account matches the repo owner. Run this once now — don't wait for a push failure:

```bash
gh auth status 2>&1 | grep "Logged in to github.com account"
```

If the active account is not `${GITHUB_PERSONAL_USER}`, switch before continuing:

```bash
gh auth switch --user "${GITHUB_PERSONAL_USER}"
```

---

## Step 2 — Handle uncommitted changes (per repo)

For each repo with `CHANGES > 0`:

1. **Filter noise files first.** Before showing the diff, strip known noise patterns from the changed-file list:

   ```bash
   git -C <repo> status --short \
     | grep -vE '(^.{3}\.DS_Store$|^.{3}\.claude/|^.{3}\.cursor/|^.{3}\.idea/|\.pyc$|/__pycache__/)'
   ```

   If only noise files remain after filtering, skip this repo — no action needed. Do not surface noise-only repos in the ask loop.

2. Show the filtered diff: remaining files only, via `git -C <repo> diff --stat`
3. Ask: commit these changes, discard them, or leave for next session?
4. If committing: run the standard commit flow (stage relevant files, write message, push)
5. If leaving: note it in the session summary as "pending"

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

If notes are on a branch that hasn't merged, flag this prominently — the next session will start blind. If the push fails with an auth error, switch to the personal GitHub account first: `gh auth switch --user <personal-user>`.

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

Before invoking, annotate each skill with its source (`global: ai-skills` or `project: <repo>`) using:

```bash
ls ~/.claude/skills/<name>/   # present → global: ai-skills
find ~/Projects -maxdepth 4 -path "*/.claude/skills/<name>" -type d 2>/dev/null  # project
```

Pass the annotated list as SA1 context. Then invoke the `skill-review` skill.

**After skill-review returns:** Any Tier 1 findings (clear bugs, broken flows, skill missed entirely) must become tickets via `issue-create` Path B targeting `${GITHUB_PERSONAL_USER}/ai-skills` **before moving to Step 7**. Do not defer Tier 1 items silently — a ticket preserves context even if not worked this session. Tier 2/3 findings can be ticketed or deferred at your discretion.

---

## Step 7 — Permission-prompt hygiene

Ask: "Want to run a permission-prompt hygiene pass? It scans recent transcripts and adds an allowlist to reduce repetitive approval prompts — takes about a minute."

- If **yes** → invoke the `fewer-permission-prompts` skill _(built-in — Claude Code)_
- If **no** → move on without friction

---

## Step 8 — Lean context audit

Reflect on context discipline. Exempt: session-close itself. Flag if observed: long thread without `/compact`; multiple unrelated tasks in one session; wide file scans; raw TF/log output without `clog`; Opus for Sonnet-class tasks. Report one line ("context stayed disciplined" or the patterns noticed) for the Step 10 summary.

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

**Ordering — always comment before transitioning, for every ticket system (Jira, Linear, GitHub):**

1. Add the comment (closing note, status update, PR link, etc.)
2. Verify the comment was created (check the response from the MCP or CLI)
3. Then transition the status

Never run the comment and transition in parallel. A failed comment on a closed ticket has no audit trail — the ticket closes without context, which is worse than leaving it open. If the comment fails, keep the ticket open and flag it in the session summary.

For Jira: call `jira_get_transitions` first to get valid transition IDs (never guess — IDs vary per project), then `jira_add_comment` → `jira_transition_issue`. For GitHub: `gh issue comment` → `gh issue close`. For Linear: `save_comment` → `save_issue`. Update `status` in `_task-index.jsonl` to reflect the new state.

**If no matches are found**: skip silently — no open question needed.

---

## Step 10 — Session summary

Produce a brief close-out summary using the template in [references/session-summary-template.md](references/session-summary-template.md). Save to `~/Projects/personal/memex/Outputs/Session/session-close-[date].md` if non-trivial.

Before writing the file, ensure the output directory exists:

```bash
mkdir -p ~/Projects/personal/memex/Outputs/Session
```

After writing the new file, prune files older than 14 days — they've been consumed by at least one subsequent session and have no remaining handoff value:

```bash
find ~/Projects/personal/memex/Outputs/Session -name "session-close-*.md" -mtime +14 -delete && \
echo "✓ pruned old session files"
```

If no files are pruned, suppress the output — no action needed means no report needed.
