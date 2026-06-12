---
version: 1.5.2
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
- `AHEAD_BRANCHES` — count of remote branches ahead of main/master where the tip commit author matches `git config user.email`; team branches from other contributors are excluded

**If only one repo is flagged, or the session was clearly scoped to a single repo** (e.g. the workspace contains only one folder, or the entire conversation was in one project context), skip the question and proceed automatically. When multiple unrelated repos are flagged and context is ambiguous, ask with labeled options — not an open-ended question:
> **Which of these repos did you work in this session?**
>
> - **All of them**
> - **[list each repo as its own option]**
> - **None — just clean up noise**

---

Before Steps 2–4, invoke the `git-ops` skill _(personal — ai-skills repo)_ — it covers branching rules, commit format, PR format, and pre-commit checks. The short version: work GitHub and GitLab repos always get a branch + PR; personal KB uses branch + PR like work repos. Full rules in `~/.claude/references/branching.md`.

**Do not ask for confirmation before invoking git-ops.** It is a required pre-flight for every session-close run.

**SSH port-22 fallback**: For all GitHub/GitLab SSH remote operations, use `scripts/git-ssh-fallback.sh <repo-path> <subcommand> [args...]` instead of raw `git`. It auto-detects port-22 blocks, switches to HTTPS, and retries transparently.

**GH auth pre-flight (personal repos):** Before processing any GitHub.com repo, verify the active account matches the repo owner. Run this once now — don't wait for a push failure.

First, ensure `GITHUB_PERSONAL_USER` is set — it must be exported before any `gh` call. If it's not in the environment, read it from local config:

```bash
if [[ -z "${GITHUB_PERSONAL_USER:-}" ]]; then
  GITHUB_PERSONAL_USER=$(jq -r '.accounts.personal.github_user // empty' \
    ~/.config/ai-skills/local.json 2>/dev/null)
fi
export GITHUB_PERSONAL_USER
```

If still empty after this, stop and ask the user to set `GITHUB_PERSONAL_USER` in their shell profile or `~/.config/ai-skills/local.json` — all personal GitHub operations depend on it.

Then verify the active account:

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
3. Ask with labeled options — do not use an open-ended question:
   > **`<repo-name>` has uncommitted changes. What would you like to do?**
   > - **Commit** — stage and commit now, then push
   > - **Leave for next session** — note in summary as pending
   > - **Discard** — revert all changes (confirm destructive)
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
   - Push the branch first — **always push before checking for or creating a PR**. The `AHEAD_BRANCHES` count from Step 1 is a point-in-time snapshot; the actual remote state takes precedence.

     ```bash
     # GitHub SSH remotes:
     bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh <worktree-path> push -u origin <branch>
     # HTTPS remotes or other hosts:
     git -C <worktree-path> push -u origin <branch>
     ```

   - Before creating a PR, verify the branch actually exists on the remote — a stale local tracking ref can make it appear pushed when it isn't:

     ```bash
     git ls-remote --heads origin <branch>
     ```

     If the output is empty, the branch is not on the remote. Push it now before proceeding. If the push fails, stop and surface the error — do not attempt PR creation against a missing branch.

   - After confirming the branch is on the remote, check whether a PR already exists (a branch that looked "ahead" in Step 1 may have had its PR merged since the scan):

     ```bash
     GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}") \
       gh pr list --head <branch> --state all --json number,state,title
     ```

     If a merged PR is returned, skip PR creation and go straight to branch cleanup. If none exists, create the PR.

   - Create a PR (use `gh pr create` for GitHub repos)
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
2. Push any unpushed commits before checking PR state — the `AHEAD_BRANCHES` count from Step 1 may be stale. After pushing, verify with `git ls-remote --heads origin <branch>` that the branch is actually on the remote before attempting PR creation.
3. If it's a feature branch: check whether a PR already exists (`gh pr list --head <branch> --state all`) before creating one
4. If it's a capture branch (e.g. `captures-2026-05-15`): this is expected for Memex — but verify commits are pushed
5. If the branch should be on main: guide through merge or PR creation

---

## Step 5 — Prune dead worktrees and merged branches

**Worktree cleanup** — for each repo that had `WORKTREES > 0`:

```bash
git -C <repo> worktree prune
```

Before running, ask with labeled options:
> **Prune stale worktree dirs in `<repo-name>`?**
>
> - **Yes, prune** — run `git worktree prune` now
> - **Skip** — leave worktrees as-is

After pruning, verify: `git -C <repo> worktree list` should show only the main worktree (plus any you intentionally kept open).

**Local branch cleanup** — for each repo worked in this session, delete local branches whose remote tracking ref is gone (i.e., the remote branch was deleted after merge):

```bash
git -C <repo> fetch --prune origin
git -C <repo> branch -vv | grep ': gone]' | awk '{print $1}' | xargs -r git -C <repo> branch -d
```

The `-d` flag only deletes fully-merged branches — unmerged ones are left alone. If a branch shows as gone but wasn't merged (e.g., force-deleted remote), use `-D` only after confirming the work is captured elsewhere.

When more than 3 branches would be deleted, show the list and ask with labeled options before proceeding:
> **Delete these `N` merged local branches in `<repo-name>`?**
>
> - **Yes, delete all** — run the cleanup now
> - **Let me pick** — list each branch for individual confirmation
> - **Skip** — leave local branches as-is

---

## Step 6 — Skill hygiene review

Invoke `skill-review` _(personal — ai-skills repo)_ in session-audit mode. It will reflect on the current conversation to find skill friction, missed triggers, and ungapped workflows worth turning into new skills. Findings always become tickets before being worked or deferred.

**Reminder**: ai-skills is a public repo. Ticket content must be scrubbed of Employer-internal hostnames, internal ticket keys used as examples, security details, and anything sensitive. skill-review enforces this — but flag it here so it's visible without reading that skill.

Before invoking, annotate each skill with its source (`global: ai-skills` or `project: <repo>`) using:

```bash
ls ~/.claude/skills/<name>/   # present → global: ai-skills
find ~/Projects -maxdepth 4 -path "*/.claude/skills/<name>" -type d 2>/dev/null  # project
```

Pass the annotated list as SA1 context. Then invoke the `skill-review` skill — **do not ask for confirmation before invoking; it runs automatically as part of session-close.**

**After skill-review returns:** Any Tier 1 findings (clear bugs, broken flows, skill missed entirely) must become tickets via `issue-create` Path B targeting `${GITHUB_PERSONAL_USER}/ai-skills` **before moving to Step 7**. Do not defer Tier 1 items silently — a ticket preserves context even if not worked this session. Tier 2/3 findings can be ticketed or deferred at your discretion.

---

## Step 7 — Permission-prompt hygiene

Invoke the `fewer-permission-prompts` skill _(built-in — Claude Code)_ automatically — no confirmation needed. It scans recent transcripts and adds an allowlist to reduce repetitive approval prompts. Takes about a minute and always safe to run.

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
