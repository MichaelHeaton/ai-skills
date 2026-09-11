---
version: 1.21.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: session-close
description: Safely close out a Claude Code session across all active repos. Checks repos in the active VS Code workspace (falls back to ~/Projects if no workspace file found) for uncommitted changes, unmerged worktree branches, and stale worktree dirs — then guides through commit, push, PR, and merge for each. Also updates any in-progress tickets touched this session and produces a session-end summary so the next session starts with full context. Trigger on: "wrap up", "close out this session", "end of session", "I'm done for today", "session close", "before I close", "session cleanup", "closing up", "wrap this up", "done for the day", "ending this chat", "finishing up", or any request to clean up repos or close out work before ending a Claude chat.
compatibility: gh CLI preferred; falls back to mcp__github__* MCP tools when absent (see "gh CLI availability" below). glab CLI, git. Atlassian MCP needed only if Jira tickets were worked on.
---

Close out this session safely. The goal: nothing stranded in branches, all tickets reflect current state, next session starts with complete context.

> **Setup dependencies** — Steps 1–5 (git hygiene) work in any repo. Steps 6–7 require ai-skills installed (`make install-system`). Steps 9–10 assume a personal memex vault (default `~/Projects/personal/memex/`) with `_task-index.jsonl` — adapt those paths to your own notes setup if different.

**Resolving the vault path.** Steps below use `$MEMEX_ROOT` for the vault location. Resolve it once at the start of the session instead of assuming the workstation path — this matters most in remote/cloud sessions, where the repo checks out to a session-specific path instead:

```bash
MEMEX_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)"
[[ -f "$MEMEX_ROOT/Raw/_task-index.jsonl" ]] || MEMEX_ROOT=~/Projects/personal/memex
```

Falls back to the standard workstation path when `$PWD` isn't a memex checkout (or `git rev-parse` fails). On a normal workstation session this resolves to the same directory as the hardcoded default, so nothing changes there.

**No local vault at all?** Check `[[ -d "$MEMEX_ROOT/Raw" ]]` once, right after resolving the path above — same test `issue-create`'s `append-task-index.sh` already uses. A cloud/web session commonly has no local memex clone, which leaves Step 9's task-index lookup with nothing to query. Set a `NO_VAULT=1` flag here if the check fails — Steps 9 and 10 below cover what to do about it; nothing needs to happen at this point beyond setting the flag, since there's no session activity yet to record.

**gh CLI availability.** Some environments (Claude Code Remote/cloud sessions) have no `gh` binary at all — not just unauthenticated. Check once, before Step 1:

```bash
command -v gh >/dev/null 2>&1 && echo present || echo absent
```

If absent, every `gh`-dependent step in this skill (the branch-hygiene PR checks below, Step 1b's auth pre-flight, Steps 3–4's push/PR creation, Step 9's ticket cross-referencing, Step 10's ticket filing) has an `mcp__github__*` MCP equivalent — see git-ops's "gh CLI availability" section for the PR-command table, and issue-create's [gh-mcp-fallback.md](../issue-create/references/gh-mcp-fallback.md) for the issue-command table (`issue-create` itself already detects and falls back automatically, so Step 10's ticket-filing needs no extra handling here). `gh pr merge`, `gh auth switch`, and `verify-closes.sh` have no MCP substitute **as far as this doc has verified** (git-ops covers this) — if the actual connected GitHub MCP server in a given session exposes a merge tool, prefer it and update this note; don't assume this list is permanently exhaustive. Note affected steps as blocked-pending-gh in the Step 10 summary rather than skipping them silently.

**No `~/.config/ai-skills/local.json`?** `GITHUB_PERSONAL_USER` (used in Step 1b's auth pre-flight and Steps 6, 9, 10 for personal-repo/account routing) has no fallback when this file doesn't exist — common in a fresh cloud/remote session. Check once:

```bash
[[ -f ~/.config/ai-skills/local.json ]] || echo "no local config — GITHUB_PERSONAL_USER unset"
```

If unset, ask the user for their personal GitHub username before any step needing `${GITHUB_PERSONAL_USER}`, rather than guessing or leaving it blank.

**Context check before starting**: session-close runs at the tail of what's often an already-long session — the multi-repo scan and Step 6's skill review add real weight on top of that. If this has been a long conversation (many tool calls, multiple tasks), say so before beginning — as a user action, not something the agent can trigger, since `/compact` is a slash command only the user can run: *"This has been a long session — consider typing `/compact` now for a controlled compact before this checklist adds more weight, then say continue. Otherwise I'll proceed as-is."* Proceed with whatever they answer — don't block on it.

**Check the most recent same-day summary before starting.** Before Step 1, search for an existing today-dated session-summary ticket rather than assuming this is the day's first run — a second same-day run is common. Run `detect-context.sh` once now (Step 10 will reuse the same routing **when this session touched only one routing target** — see the multi-repo note below) and search that target for a `session-summary` ticket titled with today's date, e.g. for a GitHub target: `gh issue list --repo <owner/repo> --label session-summary --search "Session close summary — <today's date>" --state all --json number,title,url,body` (no `gh`? see the gh-availability note above). For a Jira target, `jira_search_issues(jql="project=<key> AND summary ~ \"Session close summary — <today's date>\" ORDER BY created DESC")`. If found, read it first: it may still have unresolved items (a declined decision, an unticketed bug, a scoping question) from earlier today that this run needs to carry forward — comment on the existing ticket in Step 10 instead of filing a duplicate.

**Multi-repo sessions — one target, chosen deliberately, not whatever `$PWD` happened to be at start.** `detect-context.sh` resolves a single routing target from wherever it's run. A session that touches a mix of repos (a work-org repo and personal GitHub repos, say) still needs exactly one place for the close-out ticket — don't silently let an accidental starting directory decide it. Pick the target repo with the most session activity (most commits/tickets touched this session); if that's a tie or unclear, ask the user once rather than guessing. File the single close-out ticket there, and have it list every repo touched this session in its body — don't split one session's summary across multiple tickets in multiple systems.

**If two sessions independently file same-day summary tickets** — a race under concurrent sessions, since the check above is a snapshot — don't just let both stand. Once noticed (the freshness re-check most issue-create paths already run before confirming, or a later session's own same-day search), diff the two: if one is a strict subset of the other, close it as a duplicate with a comment pointing to the other; if they diverge, comment the missing content onto the ticket you keep, then close the other as a duplicate — never leave both open silently.

**Also check the most recent prior-day summary for known-pending blockers scoped to the repos in this session.** Fetch it (via `gh issue view`/`jira_get_issue`, not a file read) and read its "Pending" / "needs attention" section for items matching repos this session will touch, and surface any matches up front — don't make the user (or yourself) re-diagnose a blocker that was already solved and documented one session ago.

## Step 1 — Discover repos with open work

```bash
bash ~/.claude/skills/session-close/scripts/discover-repos.sh
```

This scans repos in the active VS Code workspace (detected via `*.code-workspace` file in `$PWD`, then `~/Projects/workspace/*.code-workspace`, then a depth-3 search under `~/Projects/`) and prints only those that need attention. Falls back to the full `~/Projects/` sweep if no workspace file is found anywhere. Parse the output to build a working list.

**Single-repo sessions hard-exclude `RECENT:n` sweep noise by default.** When the workspace has exactly one folder, the script already narrows the working set itself: `RECENT:n` repos found only by the broad `~/Projects/` sweep (not the workspace's own folder or the current repo) are left out of the output entirely — they're stale archive repos, not part of this session. This is a real exclusion, not just "skip the question" below. If the session is clearly single-repo-scoped from conversation context alone (no workspace file, or a multi-folder workspace where only one folder is actually in play), re-run with `SESSION_SINGLE_REPO=1` to get the same narrowing. **For a session scoped to more than one specific repo** (N>1) by conversation context alone, with no workspace file to infer it from, use `SESSION_SCOPED_REPOS="repoA,repoB"` (names under `~/Projects/`, or absolute paths) instead — same `RECENT:n` narrowing, generalized to the named set rather than only a single repo. The excluded repos are never lost — re-run with `SHOW_ALL_REPOS=1` to see them, which is what the "Show all repos" option below does.

For each line, extract:

- `REPO` — absolute path
- `BRANCH` — current checkout branch
- `CHANGES` — count of uncommitted files
- `WORKTREES` — count of active extra worktrees
- `AHEAD_BRANCHES` — count of remote branches ahead of main/master where the tip commit author matches `git config user.email`; team branches from other contributors are excluded
- `RECENT` — `y` if the repo had a commit within the last 8 hours (configurable via `RECENT_HOURS` env var); `n` otherwise

**Prioritise recently-active repos**: Sort results so `RECENT:y` repos appear first. If all flagged repos are recent (or none are), present them in the order returned by the script.

**If no repos have `RECENT:y`**, present the full flagged list with a note: *"No repos had commits in the last 8 hours — showing all repos with open work."*

**If only one repo is flagged, or the session was clearly scoped to a single repo** (e.g. the workspace contains only one folder, or the entire conversation was in one project context), skip the question and proceed automatically. When multiple unrelated repos are flagged and context is ambiguous, ask with labeled options — not an open-ended question:
> **Which of these repos did you work in this session?**
>
> - **All of them**
> - **[list each recently-active repo as its own option]** *(RECENT:y repos listed first)*
> - **Show all repos** *(re-runs Step 1 with `SHOW_ALL_REPOS=1` to surface `RECENT:n` sweep repos excluded by default in single-repo sessions, plus any filtered out as not recent)*
> - **None — just clean up noise**

### Branch hygiene check

**gh keyring health check (once, before the loop below).** A broken macOS keychain/keyring backend can make `gh` fail even though it's installed and was previously configured — distinct from `gh` being entirely absent (a separate, unrelated failure mode). Verify `gh` is actually authenticating before relying on it for this whole check:

```bash
gh auth token >/dev/null 2>&1 && gh api user >/dev/null 2>&1
GH_AUTH_BROKEN=$?
```

Use `gh api user`, not `gh pr list`, for this probe — `gh pr list` fails with a repo/remote-detection error when run outside a `gh`-recognized GitHub repo, which is unrelated to keyring health and would false-positive this whole check if the session's current directory isn't one of the repos being scanned. `gh api user` only tests auth, independent of `$PWD`.

If `GH_AUTH_BROKEN != 0`, don't silently skip branch hygiene — print the failure explicitly with a recovery hint, then fall back to a pure-git check per repo instead of the `gh pr list` flow below:

> ⚠️ `gh auth token` / `gh pr list` failed — the `gh` keyring may be broken. Try `gh auth refresh`, or see the `gh-account-routing` skill for account/keyring recovery.

Pure-git fallback, run for each repo in scope (no `gh` calls):

```bash
DEFAULT_BRANCH=$(git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[[ -z "$DEFAULT_BRANCH" ]] && DEFAULT_BRANCH="main"
CURRENT_BRANCH=$(git -C <repo> branch --show-current)
git -C <repo> status --short
git -C <repo> fetch --prune origin 2>/dev/null
git -C <repo> branch -vv | grep ': gone]'
```

- **`CURRENT_BRANCH != DEFAULT_BRANCH`** → flag drift the same way the PR-based check would: *"Checked out on `<CURRENT_BRANCH>` in `<repo-name>`, not `<DEFAULT_BRANCH>` — cannot confirm PR/merge state without `gh`, but this needs a look before the next session."*
- **`git status --short` non-empty** → surface as uncommitted changes per Step 2, same as any other repo.
- **Any `: gone]` line from `git branch -vv`** → candidate for the Step 5 local-branch cleanup (remote deleted after merge), same handling as the normal flow.

This fallback cannot distinguish "merged PR, stale checkout" from "no PR yet, still in progress" — it only catches drift and gone-remote branches via git alone. Note that limitation plus the auth failure itself in the Step 10 "Pending" summary, so the next session knows branch hygiene ran degraded and `gh` needs attention. Retry the `gh` health check at the top of a later step if it's needed again (e.g. Step 1b's account pre-flight) rather than assuming it's still broken.

**If `gh` is healthy**, run the normal PR-based check below. For each repo where `BRANCH != main` and `BRANCH != master`, check whether the current branch already has a merged or open PR — the session may have ended without switching back to main:

```bash
gh pr list --head <branch> --state all --json number,state,title \
  --repo <owner>/<repo>
```

- **Merged PR found** → before flagging just a stale branch, check whether the branch also carries commits the merged PR never brought into `main` — pushed after the PR's own merge point, or added to the branch afterward, either way invisible to `main` and undetected by any other check:

  ```bash
  git -C <repo> fetch origin --quiet 2>/dev/null
  git -C <repo> log origin/main..<branch> --oneline
  ```

  - **Non-empty** → before flagging, rule out the squash-merge false positive: a squash-merged commit lands on `main` with a different hash, so `origin/main..<branch>` can be non-empty even though the content already landed. Cross-check with the same verification Step 5 uses for squash-merged branches ([references/merged-branch-push-safety.md](references/merged-branch-push-safety.md) § Squash-merged local branches) — `git cherry main <branch>` plus a content diff scoped to the branch's own touched files, not a full-tree diff. If that confirms the content already landed, this is **not** a stranded commit; skip the flag below. Only if the content genuinely isn't on `main` are these stranded commits: real work that exists only on this branch, with no open or merged PR left to pull it into `main`. Flag prominently: *"Branch `<branch>` in `<repo>` has N commit(s) not reachable from `main` despite its PR already being merged — stranded, will be silently lost if the branch is ever deleted."* Recovery: cherry-pick them onto a fresh branch off `main` and open a new PR (git-ops's merged-branch recovery), or get explicit confirmation the commits are intentionally abandoned before Step 5 touches this branch. Include in Step 10 under "Branch hygiene," called out separately from the plain stale-branch case below.
  - **Empty** → the plain stale-branch case: *"Branch `<branch>` in `<repo>` has a merged PR — you are still checked out on a stale branch. Switch to `main` before starting the next session."* Include in Step 10 summary under a "Branch hygiene" header.
- **Open PR found** → no action; this is expected while the PR is in review.
- **No PR found, and the branch is stale** (long-lived with no recent commits, real unmerged content) → don't assume it's abandoned just because no PR exists. Push it and open a PR now, or confirm abandonment explicitly with the user — a branch can sit stale for months with genuine work never surfaced anywhere else.
- **No PR found, and the branch is actively in progress** → no action.
- **No PR found under the branch's own name, but `git log origin/main..<branch>` is also empty** (the branch's content already exists on `main`) → before treating it as active or deleting it as stale, check whether its commits landed via a *differently-named* branch: `gh pr list --search "<branch>" --state merged --json number,headRefName,mergeCommit` or a content-diff check against recent merged PRs. This is the case where the fix genuinely already landed — it just wasn't via a PR carrying this branch's own name — not a "no PR found" no-action case.
- **PR found but its state is `CLOSED`, not `MERGED`** → treat as intentionally abandoned, not stale-and-forgotten. Confirm with the user before any destructive action (branch deletion) rather than assuming a closed PR means safe-to-delete-silently — a large diverged diff especially deserves an explicit check before discarding.
- **The branch name is reused across multiple merged PRs** (a batching branch reused over several months, each cycle its own merge) → a single PR-state check on the branch name doesn't tell you which cycle's content is actually still there. Verify per-entry against `main` instead of trusting one aggregate state.

Run this check for GitHub repos only. Skip GitLab, Bitbucket, or repos with no `gh`-reachable remote. Do not block on errors — if `gh` fails for a repo, skip it silently and note it in the Step 10 summary.

### Concurrent-session check (best-effort, non-blocking)

Before committing anything in a repo, check for a second session already operating on it — a stale-state check alone only catches a *past* session, not one running right now. **Hard gate, per repo, not a one-time audit**: do not begin Step 2 for a given repo until this check has completed for that specific repo, and its actual `LIVE`/`STALE`/`CLEAR` output line — not a paraphrase of it — is what satisfies the gate.

**Name the script, don't rely on recalling it from the reference doc's filename.** Run it directly:

```bash
bash ~/.claude/skills/session-close/scripts/check-concurrent-session.sh <repo>
```

Full detection commands, signal handling, and the gate's interaction with stale-branch resolution: [references/concurrent-session-check.md](references/concurrent-session-check.md).

### Transcript-vs-working-tree reconciliation check

`discover-repos.sh`'s `CHANGES` count is a snapshot of the working tree, not of what this session actually did — a concurrent session sharing the same non-worktree checkout can pick up this session's own uncommitted Edit/Write changes into its own `git stash`, silently, before either session commits them. The working tree then looks clean and `CHANGES` reads low, even though real edits from this session are gone. For every repo this session made Edit/Write calls against, reconcile the transcript's own record of what was touched against the repo's actual state before trusting a clean result: procedure, mismatch handling, and stash/reflog recovery: [references/transcript-reconciliation.md](references/transcript-reconciliation.md).

---

## Step 1b — Git-ops pre-flight

Invoke the `git-ops` skill *(global: ai-skills)* before Steps 2–4 — it covers branching rules, commit format, PR format, and pre-commit checks. The short version: work GitHub and GitLab repos always get a branch + PR; personal KB uses branch + PR like work repos. Full rules in `~/.claude/references/branching.md`.

**Do not ask for confirmation before invoking git-ops.** It is a required pre-flight for every session-close run.

**"Invoke" means an actual `Skill` tool call, not recalling git-ops's rules from this section's own inlined summary.** Git hygiene run correctly from memory — because this section already restates git-ops's key rules inline — satisfies the *outcome* but not this pre-flight: git-ops's own freshness gate (AGENT.md check, humanizer pass on the PR description) only actually runs when the skill itself fires, and recalling its rules by memory silently skips that gate even when every git command that session ran was correct. If you're not certain the `Skill` tool was actually called for git-ops this session, call it now before proceeding.

**Enforcement mechanism — named the same way the branch-identity check below is.** This isn't only a prose reminder: `ai/claude/hooks/git-ops-reminder.py` (a `PreToolUse` hook on `Bash`) nudges before any bare `git commit`/`git push`/`gh pr create`/`glab mr create` if git-ops hasn't fired yet this session, and `ai/claude/hooks/git-ops-track.py` (a `PostToolUse` hook on `Skill`) records the session-scoped flag file (`~/.claude/.git-ops-sessions/<session_id>`) that tells the reminder hook whether it already fired. If a commit/push/PR command runs without a visible `[git-ops]` advisory first, that's this hook pair's signal firing (or failing to) — treat a missing advisory as a reason to double-check the `Skill` tool was actually called, not as confirmation it was.

**Branch-identity check — name the script, don't rely on recalling git-ops's full body.** For every non-worktree repo in scope, before Step 2's commit flow begins for that repo, run it directly:

```bash
bash ~/.claude/skills/git-ops/scripts/check-branch-identity.sh <repo-path> <expected-branch>
```

`<expected-branch>` is whatever branch this session most recently created or checked out for that repo (Step 1's `BRANCH` field, unless a later step switched it) — **re-derive it fresh via `git -C <repo> branch --show-current` at this point, don't reuse a value only recalled from earlier conversation turns.** In a multi-root workspace especially, the branch this session believes it's on can drift from what conversation memory says by the time Step 1b actually runs; a fresh git-sourced snapshot is the only reliable baseline. `MATCH` or `WORKTREE:<actual>` → proceed to Step 2. `MISMATCH:<actual>` → stop before committing; the active branch changed unexpectedly in a shared checkout, so confirm which branch is actually correct first. This is the same check git-ops's "Shared checkout branch-identity check" section documents — it's called out here by name because a generic "invoke git-ops" instruction has been recalled without this specific script call actually firing.

**SSH port-22 fallback**: For all GitHub/GitLab SSH remote operations, use `bash ~/.claude/skills/session-close/scripts/git-ssh-fallback.sh <repo-path> <subcommand> [args...]` instead of raw `git`. It auto-detects port-22 blocks, switches to HTTPS, and retries transparently.

**GH auth pre-flight:** Before processing any GitHub.com repo — personal or work/org — verify the active `gh` account matches that repo's owner and switch if needed, restoring the original account in Step 10. Full account-detection and switch commands: [references/gh-auth-preflight.md](references/gh-auth-preflight.md). This is the session-boundary version of the same check — for a mid-session `gh` call outside a session-close run, use the `gh-account-routing` skill *(global: ai-skills)* instead.

---

## Step 2 — Handle uncommitted changes (per repo)

**Committing on a branch Step 1 already flagged as having a merged PR may land on a freshly created branch instead of the stale checkout** — a pre-commit hook can auto-create a new branch as recovery when it detects this. That's expected recovery behavior (git-ops's merged-branch recovery), not a failure — if the commit lands somewhere other than the branch you expected, check whether this is why before treating it as an anomaly.

For each repo with `CHANGES > 0` **whose Step 1 branch-hygiene check has already completed for that repo**:

1. **Filter noise files first.** Before showing the diff, strip known noise patterns from the changed-file list:

   ```bash
   git -C <repo> status --short \
     | grep -vE '(^.{3}\.DS_Store$|^.{3}\.claude/|^.{3}\.cursor/|^.{3}\.idea/|\.pyc$|/__pycache__/)'
   ```

   If only noise files remain after filtering, skip this repo — no action needed. Do not surface noise-only repos in the ask loop.

2. **Check for gitignore candidates.** If `git status --short` shows any `??` (untracked) files, ask before treating them as commit candidates:
   > **`<repo-name>` has untracked files. Do any of these belong in `.gitignore`?**
   > - **Yes — add to .gitignore** — add paths/patterns now, then commit `.gitignore`; re-run status to see what remains
   > - **No — treat as normal changes** — continue to step 3

3. Show the filtered diff: remaining files only, via `git -C <repo> diff --stat`
4. Ask with labeled options — do not use an open-ended question:
   > **`<repo-name>` has uncommitted changes. What would you like to do?**
   > - **Commit** — stage and commit now, then push
   > - **Leave for next session** — note in summary as pending
   > - **Discard** — revert all changes (confirm destructive)
5. If committing: run the standard commit flow (stage relevant files, write message, push)
6. If leaving: note it in the session summary as "pending"

**Pre-commit hook blocked by pre-existing, unrelated debt.** If a hook fails on content this commit didn't touch — e.g. a markdownlint hook blocking a one-line, unrelated change because of broken links elsewhere in the same file that predate this session — this is a "hook blocks a small unrelated commit due to pre-existing debt" pattern, not specific to any one linter. Don't silently expand scope to fix the debt inline under time pressure. Pick one: **split a minimal separate fix commit** scoped only to what the hook actually demands, then retry the original commit; or **note the blocker in the Step 10 summary as pending debt** and leave the original change for next session if a minimal fix isn't safely scoped. Never reach for `--no-verify` to route around this (git-ops's pre-commit checks).

**Agent git blocked by a Cursor hook JSON/stdout mismatch — distinct from the pre-existing-debt case above.** If Cursor's own hook plumbing blocks the agent's git commands outright (a hook JSON/stdout shape mismatch, not a lint failure on real content), don't stall the checklist waiting on it: surface copy-paste commands for the user to run directly in their own terminal, then continue session-close from the next step once they confirm the command ran. Log the interruption in Step 10's Pending section so it isn't silently lost.

**Drafts meant for manual human follow-up (wiki pastes, external-system content) need a durable home, not a scratchpad.** Any output this session is deferring to a future session for manual action — "paste this into the wiki," "someone needs to copy this into X" — should be written to a durable, git-tracked location (e.g. `Outputs/Drafts/` in the relevant repo) rather than left at an ephemeral scratchpad path. A scratchpad gets cleaned up between sessions with no warning; a genuinely finished draft sitting there can be lost outright, not just inconvenient to re-find. If such a draft already exists at a scratchpad path when Step 10 runs, copy it to the durable location before writing the summary, and flag it in the Pending section as an **at-risk item needing relocation** — not a normal pending task — so it can't be silently dropped by a routine scratchpad cleanup.
7. If discarding, use concrete commands — never `rm -rf`, which some workstations block outright via a recursive-delete safety hook:

- Tracked changes: `git -C <repo> restore <file>` (or `git -C <repo> checkout -- <file>`)
- Untracked files/dirs inside the repo: `git -C <repo> clean -fd`
- An untracked directory the user wants gone entirely, outside git's own reach: prefer `trash <path>` over `rm -rf <path>`
   This only applies to explicit user-requested deletion of untracked content flagged in step 2 above — it is not a substitute for `git clean` on tracked/ignored files.

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

3. For worktrees with committed but unpushed work — **check merged-PR state before pushing**, per git-ops's "Before pushing to an existing branch" rule. The `AHEAD_BRANCHES` count from Step 1 is only a point-in-time snapshot, so don't skip this check just because Step 1 flagged the branch as ahead. Merged-PR check, the correct push command per remote type, and post-push landing confirmation: [references/merged-branch-push-safety.md](references/merged-branch-push-safety.md). Once pushed and confirmed, create a PR (use `gh pr create` for GitHub repos).
4. For worktrees with uncommitted changes: handle via Step 2 flow first, then push + PR
5. For worktrees with no new commits (already merged or empty): skip — handled by prune in Step 5

**Memex-specific check**: After handling worktrees, verify that this session's vault notes and task index entries are reachable from `main`. Run:

```bash
git -C "$MEMEX_ROOT" log main..HEAD --oneline 2>/dev/null
```

If notes are on a branch that hasn't merged, flag this prominently — the next session will start blind. If the push fails with an auth error, switch to the personal GitHub account first: `gh auth switch --user <personal-user>`.

---

## Step 4 — Handle non-main branch checkouts

For each repo where `BRANCH != main` and `BRANCH != master` and `WORKTREES == 0`:

1. Show what's on the branch vs main: `git -C <repo> log main..HEAD --oneline`
2. **Check merged-PR state before pushing** any unpushed commits — the `AHEAD_BRANCHES` count from Step 1 may be stale, and pushing to an already-merged branch orphans commits (per git-ops's "Before pushing to an existing branch" rule). Same check and recovery as Step 3: [references/merged-branch-push-safety.md](references/merged-branch-push-safety.md).
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

The `-d` flag only deletes fully-merged branches — unmerged ones are left alone. **A squash-merged branch is the far more common cause of "not fully merged" here**, not just a force-deleted remote: the branch's commits genuinely landed on `main`, but git doesn't recognize them as ancestors because the squash commit has a different hash. Before falling back to `-D`, verify the content actually landed rather than assuming — verification commands: [references/merged-branch-push-safety.md](references/merged-branch-push-safety.md).

**A batch local-branch delete can trigger Auto-review's smart-mode gate** (same pattern as `issue-update`'s bulk-ops note) — this is a safety gate on high-velocity writes, not a failed cleanup. Request approval or continue once cleared rather than treating the block as an error.

When more than 3 branches would be deleted, show the list and ask with labeled options before proceeding:
> **Delete these `N` merged local branches in `<repo-name>`?**
>
> - **Yes, delete all** — run the cleanup now
> - **Let me pick** — list each branch for individual confirmation
> - **Skip** — leave local branches as-is

---

## Step 6 — Skill hygiene review

This is the heaviest step in session-close — reviewing every skill that fired means reading each one's SKILL.md and reference files fresh, on top of a session that's often already long. Run it in the `skill-reviewer` subagent instead of the main session, so none of that reading competes with this conversation's context window.

Before delegating, annotate each skill used this session with its source (`global: ai-skills` or `project: <repo>`) using:

```bash
ls ~/.claude/skills/<name>/   # present → global: ai-skills
find ~/Projects -maxdepth 4 -path "*/.claude/skills/<name>" -type d 2>/dev/null  # project
```

Invoke `skill-session-handoff` *(global: ai-skills)* with this annotated list to assemble the SA1 context block. Then delegate that block to the **`skill-reviewer` subagent** (Agent tool, `subagent_type: skill-reviewer`) to run skill-review's SA2–SA4 in isolation. **Do not ask for confirmation before doing either step; both run automatically as part of session-close** — this includes `skill-session-handoff`'s own Step 5 "Want me to do that now?" question, which that skill itself skips when it detects an auto-delegate caller like this one.

The subagent returns only a findings table, a new-skill-ideas table, and a short summary — it does not create tickets or edit anything. **"Doesn't come back with findings" isn't one case — distinguish three, each with its own recovery path:**

- **Spawn failure or usage/quota error** (not deployed, errors out before running, hits a quota limit) → fall back to invoking `skill-review` directly in-session with the same annotated list as SA1 context: run SA2-SA4 in-session and still file tickets for every finding (SA5). Note in the Step 10 summary that the subagent failed and the in-session fallback ran, so it's visible rather than silently dropped.
- **Empty result that's actually valid** (the subagent ran cleanly and genuinely found nothing) → accept it as-is, no fallback needed. Log "no skill changes identified — nothing to ticket" in Step 10 the same as a clean in-session run would.
- **Truncated or malformed output** (a findings table cut off mid-row, unparseable structure) → resume the same subagent invocation once before falling back to the in-session path — a truncation is often a one-off, and re-running in-session throws away work the subagent may have already done correctly. Only fall back to in-session SA2-SA4 if the resume also comes back malformed.

**Reminder**: ai-skills is a public repo. Ticket content must be scrubbed of Employer-internal hostnames, internal ticket keys used as examples, security details, and anything sensitive. This scrub is the parent session's responsibility (SA5) — it does not happen inside the subagent.

**After the subagent returns:** Automatically create an ai-skills ticket for **every finding** — existing skills to improve and new skill ideas alike — without prompting for confirmation. Use `issue-create` Path B targeting `${GITHUB_PERSONAL_USER}/ai-skills`. Each ticket body must include: the finding description, proposed change, skill name + source (`global: ai-skills` or `project: <repo>`), and a one-line session context note. Run the security scrub before writing any ticket content. After all tickets are created, report: "Created N ai-skills tickets — [list with #IDs]" and continue to Step 7. If the subagent returns no findings, note "no skill changes identified — nothing to ticket" and continue.

---

## Step 6b — Memory diff review

Invoke the `memory-refine` skill *(global: ai-skills)* automatically — no
confirmation needed to *check*. It reflects on this session for
evidence-backed corrections to a project memory file
(`~/.claude/projects/<project-hash>/memory/*.md`) and proposes at most one
small diff to at most one file.

**Run this in the main session, not a subagent.** Unlike Step 6, this step
cannot be delegated: the whole point is that the proposed diff — if
`memory-refine` finds one — requires the user's explicit approve/reject in
this same conversational turn, with the user actually present to answer. A
subagent has no way to get that answer back into this turn.

The proposed diff itself always requires the user's explicit approve/reject
before it's applied — this step never auto-applies a memory edit, even
though the review that produces it runs without asking permission first.

**Carry-forward exception**: `memory-refine` tracks how many times the same
proposed diff has gone unanswered across runs (its own
`.memory-refine-pending.json` state, not owned by this skill). If it signals
a forced review (carry count reached 2 — see `memory-refine`'s Step 4a),
surface that blocking approve/reject prompt at the **top of this
session-close run's output**, ahead of the Step 1 summary and everything
else, instead of leaving it in sequence at Step 6b — and do not let this
session-close run proceed past it unanswered.

If `memory-refine` reports "no memory changes identified this session",
note that and continue to Step 7. If a diff was approved, note which file
changed in the Step 10 summary; if rejected, no action needed — the file is
confirmed unchanged.

---

## Step 7 — Permission-prompt hygiene

Invoke the `fewer-permission-prompts` skill *(built-in)* automatically — no confirmation needed. It scans recent transcripts and adds an allowlist to reduce repetitive approval prompts. Takes about a minute and always safe to run.

**Pre-allowed commands**: The transcript-scanning commands (`find`, `jq`, `cat` against `~/.claude/projects/`) are pre-allowed in `.claude/settings.json` in this repo so the skill runs without triggering permission prompts during its own analysis. If you see prompts for those commands, confirm once — they are read-only operations on local transcript files.

---

## Step 8 — Lean context audit

Reflect on context discipline. Exempt: session-close itself. Flag if observed: long thread without `/compact`; multiple unrelated tasks in one session; wide file scans; raw TF/log output without `clog`; Opus for Sonnet-class tasks. Report one line ("context stayed disciplined" or the patterns noticed) for the Step 10 summary.

---

## Step 9 — Update in-progress tickets

Do not ask the user if they worked on tickets. Find them from the task index and the session's git activity (commit messages, branch names, PR titles), then update status — comment before transitioning, never in parallel, so a failed comment never leaves a ticket closed without an audit trail. A branch/commit-message match is only a candidate; confirm via `gh pr view` that the PR itself references the ticket before asserting the linkage anywhere, including the Step 10 summary. Full procedure (index lookup query, git cross-reference, PR-verification, per-system commands for Jira/GitHub): [references/ticket-cross-referencing.md](references/ticket-cross-referencing.md).

**If no matches are found**: skip silently — no open question needed.

**If `NO_VAULT=1`** (set above): skip the task-index lookup itself — there's no index to query — but still gather the same ticket list from git/PR activity, since Step 10's summary ticket needs it regardless of vault presence.

---

## Step 10 — Session summary

**Restore original gh account first.** If `ORIGINAL_GH_ACCOUNT` was captured during the auth pre-flight (i.e. a switch happened earlier in this run), switch back now so the session doesn't end with the personal account active on repos owned by a different account:

```bash
if [[ -n "${ORIGINAL_GH_ACCOUNT:-}" ]]; then
  gh auth switch --hostname github.com --user "${ORIGINAL_GH_ACCOUNT}" 2>/dev/null || true
fi
```

**The close-out report is always filed as a labeled ticket via `issue-create` — never written to `Outputs/Session/*.md`.** This applies in every session, not only vault-less ones: a remote/web session scoped to a single repo has no memex access to write a file into, and even on a full workstation `Outputs/` is documented as ephemeral (`Outputs/README.md`) while a per-session file accumulating there indefinitely contradicts that. Filing a ticket gives every session — local or cloud — a durable, always-reachable home for the close-out record.

**If `GH_AUTH_BROKEN` was set during Step 1's branch hygiene check**, record it under "⚠️ Pending" in this summary — e.g. *"`gh` keyring broken this session (`gh auth token`/`gh pr list` failed) — branch hygiene ran on the pure-git fallback only; run `gh auth refresh` before the next session and re-verify branch/PR state normally."* This is a session-boundary fact the next session needs, not just a mid-run print — don't let it be printed once during Step 1 and then dropped.

By the time this step runs, Step 6's findings, Step 8's context note, and Step 9's git/PR-derived ticket list are all known, so this is the one point in the run with everything the record needs.

- **Nothing worth recording** (no commits, no ticket updates, no Step 6 findings, no other reportable activity this session) — skip entirely, no new ticket. This holds even if a same-day ticket already exists with unresolved items from earlier today: an empty run has nothing to add, so leave that existing ticket exactly as it stands rather than commenting "nothing new" onto it — a no-op comment isn't worth the noise, and the ticket's unresolved items remain visible on it either way.
- **Otherwise** — draft the close-out summary using the template in [references/session-summary-template.md](references/session-summary-template.md), then file it via the `issue-create` skill using its normal routing (its own Step 1 "Detect routing target" via `detect-context.sh`, or the same target already resolved above for the same-day check and the multi-repo note) — this session's own repo context decides Jira, GitHub-current-repo, or GitHub-Memex, exactly as it would for any other issue-create call; don't hardcode a fixed target. Title it `Session close summary — <date>[ - topic]`. Label it `session-summary` in addition to whatever labels that path normally applies (create the label first if the target repo doesn't have it yet — `gh label create session-summary --repo <owner/repo> --description "End-of-session close-out report" --color 5319e7`, or the GitHub MCP equivalent if `gh` is absent; ignore an "already exists" error).
  - **If `NO_VAULT=1`** (set before Step 1) and routing lands on Path C (GitHub Issue in Memex): skip Path C's C5 (`Raw/_GitHub-Issues-log.jsonl` append) — it's an unguarded write into the same `Raw/` directory this run already confirmed is missing, unlike C4 and C6 which already tolerate that. C6 itself is safe to run as normal; `append-task-index.sh` no-ops cleanly when `Raw/` is absent. Add a second label, `needs-local-session` (description: "C5's Raw/ log append was skipped — this run had no local vault clone to write it into; the ticket itself filed normally and needs no further action unless that log entry specifically matters"), so the one real gap is visible on the ticket without overstating it as the whole record being blocked.
  - If a same-day ticket was found in the pre-Step-1 check above, comment the new content onto that existing ticket instead of filing a duplicate.
- Confirm the ticket's URL (or "nothing to record") in the close-out reply — never a summary-file path.
