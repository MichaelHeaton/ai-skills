---
version: 1.20.1
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: git-ops
description: Universal git hygiene guide — fires on the *first* git commit, push, PR, or MR operation in a session and every one after, not only retroactively at session-close. Covers branching rules, commit message format, PR/MR description format, and pre-commit checks scoped to modified files (including terraform fmt). Applies regardless of which other skills are active. Trigger on: any request to commit, push, open a PR or MR, "git commit", "create a PR", "push this", "open a pull request", "submit a MR", "ready to merge", or any variation of committing or sharing code changes.
---

Apply these rules for every git operation, in every repo. They complement repo-specific conventions — if a repo has its own stricter rules, follow those instead.

> **Non-negotiable before every `gh pr create` / `glab mr create`** — even when this skill is being applied from memory rather than freshly read:
>
> 1. **AGENT.md check** — see "Before opening a PR — AGENT.md check" below
> 2. **humanizer pass** on the PR Summary/Test plan — see "PR / MR descriptions" below
>
> Both are cheap (seconds) and both have been skipped in practice when the skill was recalled rather than re-invoked. If you're not certain these already ran this session, re-invoke the `Skill` tool on `git-ops` rather than proceeding from memory.
>
> **Non-negotiable immediately after `gh pr create` / `create_pull_request`, whenever the body's Closes/Fixes/Resolves clause references more than one issue**:
>
> ```bash
> bash ~/.claude/skills/git-ops/scripts/verify-closes.sh --pre-merge <pr-number> [owner/repo]
> ```
>
> A `NOT-LINKED:<N>` line means GitHub didn't parse that reference — the exact silent failure the "Closing multiple issues from one PR" rule below exists to prevent, but caught before merge instead of after. Rewrite the clause to repeat the keyword once per issue, update the PR body, and re-run the check clean before treating the PR as ready. This runs in addition to, not instead of, the post-merge check in "Post-merge issue verification" below — that one confirms the issues actually closed; this one confirms GitHub recognized the references in the first place.

**If you already read this file fresh earlier in this session** (a formal `Skill` tool invocation, or having directly read/edited it), apply these rules directly rather than re-reading or reprinting the full body again for a second commit/PR in the same session — the freshness requirement above is about the content being current in context, not about the specific mechanism that put it there.

---

## Branching

**Always branch from the default branch (`main` or `master`). Never branch from another feature or PR branch.**

```bash
# Always
git checkout main && git pull && git checkout -b <new-branch>

# Never
git checkout <other-feature-branch> && git checkout -b <new-branch>
```

**Why:** If the source branch was squash-merged to main, its commits are rewritten as a single squash commit. A new branch from that source carries the original commits — which are already represented in main — making the net diff of any new PR resolve to zero. The result is a no-op PR that looks like changes but applies nothing.

For per-repo-type conventions (work GitHub, GitLab, personal KB, personal), see `docs/guides/branching.md` in ai-skills.

**Creating a worktree under sandbox execution:** `/tmp` is not writable in that environment — a `git worktree add /tmp/<branch>` fails outright, not with a permissions warning that's easy to miss. Use `<repo-root>/.worktrees/<branch>` instead.

**A batch `git branch -d` can trigger Auto-review's smart-mode gate** — a safety checkpoint on high-velocity writes, not a failed cleanup. Request approval or continue once cleared rather than treating the block as an unexplained error (same pattern `issue-update`'s bulk-ops note documents for ticket closes).

---

## Commit messages

Use conventional commits. Format:

```
<type>(<scope>): <short description>

[optional body — explain the why, not the what]

[optional footer — ticket refs, co-authors]
```

**Types**

| Type | When to use |
| --- | --- |
| `feat` | New capability or behavior |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance, deps, config — no behavior change |
| `refactor` | Code restructure with no behavior change |
| `test` | Adding or updating tests |
| `ci` | CI/CD pipeline changes |

**Rules**

- Subject line: imperative mood, lowercase after the type, no period, 72 chars max
- Scope is optional but useful in multi-component repos (`feat(vault):`, `fix(auth):`)
- Include the ticket key in the footer when one exists: `Refs: PROJ-XXXXX` or `Closes: #NN`
- **Before using a closing keyword (`Closes:`/`Fixes:`/`Resolves:`), confirm the referenced issue's work is actually done in this commit** — don't add it speculatively because the ticket is related or was touched earlier in the session. A closing keyword on unfinished work auto-closes a ticket that isn't actually resolved the moment the PR merges.
- Co-author line when Claude wrote the commit: `Co-Authored-By: <model name> <noreply@anthropic.com>` — use whichever model actually authored the commit; don't pin a specific version string here, since it will keep drifting as models change
- One logical change per commit — don't bundle unrelated fixes

**Examples**

```
feat(session-close): add skill hygiene review step

Closes: #28
Co-Authored-By: <model name> <noreply@anthropic.com>
```

```
fix: scope terraform fmt to modified files only
```

---

## Before opening a PR — AGENT.md check

Before running `gh pr create`, invoke the `agent-md-sync` skill _(global: ai-skills)_ in check mode to verify that component-level AGENT.md files are up to date with the changes in this branch.

```bash
bash ~/.claude/skills/agent-md-sync/scripts/check-pr-diff.sh
```

**If the script reports only `OK:` lines or no output**, proceed silently — no prompt needed.

**If the script reports any `STALE:` or `MISSING:` lines**, pause and present the warning prompt defined in the `agent-md-sync` skill (check mode, Step 2). Wait for the user's response before continuing.

**Response handling:**

- **Update/create now** — generate and stage the AGENT.md update(s); they become part of this PR
- **Skip for now** — add a `## Documentation` note to the PR description; proceed with PR creation
- **Doesn't warrant an AGENT.md** — append to `.agent-md-ignore`, stage the file, proceed

Do not skip this check. It is lightweight (pure git diff + file stat) and runs in under a second. The goal is that documentation and code travel together in the same PR.

---

## PR / MR descriptions

**Title**: same format as the commit subject — conventional prefix, imperative, ≤70 chars.

**Body structure**:

```markdown
## Summary
- <what changed and why — 1-3 bullets>

## Test plan
- [ ] <what to verify — be specific>

## Refs
- Ticket: PROJ-XXXXX / #NN
- Closes: #NN
- Related PR: #NN (if any)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**Rules**

- Summary explains the _why_, not just the _what_ — the diff shows the what
- Test plan must have at least one checkable item; "tested manually" is not enough
- Link the ticket; if there is no ticket, say so explicitly rather than omitting the section
- Keep the title short — details belong in the body
- **Closing multiple issues from one PR — repeat the keyword, never comma-list it.** GitHub only auto-closes the first issue number after a closing keyword (`Closes`, `Fixes`, `Resolves`); it does not parse a trailing comma-separated list. `Closes: #141, #134, #157` closes only `#141` — `#134` and `#157` stay open even though the PR merged, and have to be closed by hand after the fact. Repeat the keyword once per issue instead, either each on its own line:

  ```
  ## Refs
  - Closes: #141
  - Closes: #134
  - Closes: #157
  ```

  or inline per GitHub's documented multi-issue syntax: `Closes #141, closes #134, closes #157`. Same rule applies across repos — `Closes owner/repo#NN` for each cross-repo reference.
- **Verify the branch reached the remote before calling `gh pr create` / `glab mr create`**: `git rev-parse --verify -q origin/<branch> >/dev/null || git push -u origin <branch>`. A worktree branch committed by a subagent (e.g. `dev-team-coder`'s isolated worktree) often exists only in that worktree and was never pushed — `gh pr create` on an unpushed branch fails with a confusing GraphQL error (`Head sha can't be blank, Base sha can't be blank, No commits between main and , Head ref must be a branch`). Push first, then create the PR.
- **Before running `gh pr create` / `glab mr create`**, invoke the `humanizer` skill _(global: ai-skills)_ on the composed Summary and Test plan bullets — same "check before creation" pattern as the AGENT.md step above. Strips AI-writing tells while every fact, ticket ref, and checklist item survives unchanged.
- Always `cd` into the repo before running `gh pr create` — the `--repo` flag handles routing but `gh` still needs local git context to resolve the remote
- **Always pass `--repo owner/repo --head branch-name`** on `gh pr create` for any org repo — don't wait for a failure first. This isn't just an SSH-alias workaround: an org repo's ambient git context is more likely to disagree with the target repo than a personal one. (SSH alias remotes are one concrete trigger — if `origin` uses an SSH config alias, e.g. `git@github.com-personal:owner/repo`, `gh pr create` can fail with "must first push branch" even when the branch is already pushed — but the flags are the default regardless of remote type.) Full rule: [references/multi-account-operations.md](references/multi-account-operations.md).
- **Multi-account pre-flight**: see "Multi-account operations" below before running `gh pr create` on an org repo.
- **After `gh pr create`, re-query state before treating the branch as "pending review"**: `gh pr view <n> --json state,mergedAt`. Some personal repos have repo-level auto-merge enabled, so a just-opened PR can merge itself within seconds — if `mergedAt` is already set, switch back to the default branch, pull, and run local branch cleanup for it in the same pass instead of deferring that to a later check. The "always branch + PR" rule still applies even when the PR merges itself immediately; this only changes when cleanup happens, not whether the PR step is skipped.

---

## After a merge and main-sync

Right after switching to `main` and pulling post-merge, `main` is the active branch — and it's easy to carry straight on to the next edit without cutting a new branch first, since nothing about the working tree looks different yet. Before making the next edit in the same repo, confirm you're not still on `main`/`master`:

```bash
git branch --show-current
```

If it prints `main` or `master`, cut a new branch (per "Branching" above) before touching any file. A commit landing directly on `main` here is a self-inflicted violation of the branch-and-PR rule, not a git failure — recover with `git branch <new-branch> && git reset --hard origin/main` on `main` (moving the commit onto the new branch, then resetting `main` back to match `origin/main`) if it happens before pushing.

---

## Verify remote before trusting a repo search miss

A grep/search against a "known" local clone coming back empty is not proof the thing isn't tracked anywhere — the clone's remote can be a stale, abandoned mirror on a different host/org entirely, with the real source of truth living somewhere else. Before concluding a search miss against a local clone means "not tracked anywhere," confirm `git -C <repo> remote -v` matches the expected canonical origin. Most relevant in orgs/ecosystems known to have duplicate or mirror repos under different names/orgs.

---

## Shared checkout branch-identity check

Distinct from `session-close`'s concurrent-session check, which only answers "does another live process exist?" — it doesn't catch a second process **sharing this exact (non-worktree) checkout** silently swapping the active branch out from under this session. An isolated `git worktree` checkout is immune to this (its branch is pinned to that worktree); a shared/main checkout is not — a background task checking out its own branch directly in a shared working directory can silently replace the branch this session believes it's still on, and a commit can land on the wrong branch before anyone notices.

Before every `git commit`, verify the active branch is still the one this session expects (the branch named in the Architect/plan step, or the branch you last explicitly checked out or created):

```bash
bash ~/.claude/skills/git-ops/scripts/check-branch-identity.sh <repo-path> <expected-branch>
```

- **`MATCH`** — proceed
- **`WORKTREE:<actual>`** — this checkout is an isolated worktree; a branch swap in a _different_ checkout of the same repo can't collide with it here. Proceed.
- **`MISMATCH:<actual>`** — the active branch changed unexpectedly in a shared checkout. **Stop before committing.** Confirm which branch is actually correct before proceeding — do not commit onto whatever happens to be checked out.

**Mechanical enforcement, not just a manual check**: the script above is advisory — it only catches a collision if you remember to run it. `hooks/branch-guard.py` (`PreToolUse`, matcher `Bash`) enforces the same rule automatically, blocking the `git commit` call itself (non-zero exit) on a mismatch, paired with `hooks/branch-guard-track.py` (`PostToolUse`, matcher `Bash`) which updates the recorded expectation whenever this session explicitly runs `git checkout`/`git switch`.

**Installed by default in this repo (`ai-skills`)**: both hooks are wired into this repo's tracked `.claude/settings.json`, so any session working inside `ai-skills` gets the enforcement automatically — no opt-in step required. A PR here can't reach a user's live global `~/.claude/settings.json` (it's outside the repo and on Claude's own `Edit` deny-list — see `hooks/inline-bash-hooks.md`) or any _other_ repo's checkout, so that's the actual boundary of what's enforced by default: this repo's own checkouts, not every repo everywhere. For any other repo where this collision risk matters, add the same block via the `update-config` skill, routed to that repo's own `.claude/settings.json` (or to global if it should apply everywhere you work):

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/branch-guard.py" }] }
    ],
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/branch-guard-track.py" }] }
    ]
  }
}
```

A worktree checkout is exempt (its branch is pinned) — this only fires against a shared, non-worktree checkout, the same scope as the manual script above. A detached-`HEAD` checkout has no branch name to compare against, so the hook fails open there too (no baseline recorded, no block) — it's scoped to branch collisions specifically, not a general "is this checkout in the state I expect" check.

---

## Live concurrent-session detection

Distinct from the "Shared checkout branch-identity check" above, which only catches a branch swap _after_ it's already happened. Before committing, check whether a second Claude Code session is actively writing to this same repo right now — via `ps aux` for another process with `--add-dir` on this repo, plus a file-mtime check against this session's own start time. Full detection commands and the "don't touch the other session's in-progress edit; move to a fresh branch off updated main once it's done" recovery: [references/live-concurrent-session.md](references/live-concurrent-session.md). The same reference also covers a signal-triggered nudge that fires earlier than any of the above — before the first Edit/Write in a repo already showing recent-activity or branch-churn signals, not just before committing.

**A Cursor multi-tab workspace defeats process-based detection entirely** — a second chat tab in the same Cursor window can switch the shared checkout's branch out from under this session with no separate OS process to detect via `ps aux`, since both tabs share one process. In that environment, the branch-identity check above (not this process-detection check) is the primary guard, not a backstop — run it before every commit rather than treating process detection as sufficient. Prefer isolated worktrees per tab for any multi-tab session doing real work in parallel.

---

## Merging a PR

`gh pr merge <n> --squash --delete-branch` (or your repo's configured merge strategy) can fail on transient GitHub API errors — a 502, or "merge already in progress." Don't retry blindly: a transient-looking failure can mean the merge actually landed server-side, and a second merge attempt against an already-merged PR just produces a second, confusing error.

**Re-check before every retry:**

```bash
gh pr view <n> --repo <owner/repo> --json state,mergedAt
```

If `state` is `MERGED`, stop retrying — the merge succeeded. Move on to post-merge cleanup (branch switch, issue verification) instead.

**If it's still open, retry with backoff** — a few attempts, doubling the wait each time, re-checking state before each one:

```bash
for attempt in 1 2 3; do
  gh pr merge <n> --repo <owner/repo> --squash --delete-branch && break
  gh pr view <n> --repo <owner/repo> --json state,mergedAt | grep -q '"MERGED"' && break
  sleep $(( 2 ** attempt ))
done
```

If all attempts fail and the re-check still shows the PR open, stop and surface the error rather than continuing to retry silently — a merge conflict or branch protection failure won't resolve itself with more retries.

**A merge blocked outright by the Claude Code auto-mode permission classifier ("Blocked by classifier") is a different failure class from the transient-API case above** — it's a policy/permission rejection, not infra flakiness, and a retry loop can't resolve it. On a classifier block, stop retrying immediately, leave the PR open, and note it as "awaiting manual merge (blocked by permission classifier)" in the session summary rather than treating it as a retryable failure.

**A merge via the GitHub/GitLab UI or API can also hang or time out while the merge itself actually landed** — don't assume a hang means nothing happened. Before retrying, check whether the PR's head SHA is already reachable from the default branch:

```bash
git -C <repo> fetch origin --quiet
git -C <repo> merge-base --is-ancestor <head-sha> origin/main && echo "already landed"
```

- **Already landed** (exit 0 / "already landed" printed) — do not retry the merge. If the PR is still showing open, close it as already-merged rather than attempting a second merge against content that's already on the default branch. Treat the work as landed and move on to post-merge cleanup.
- **Not yet landed** — retry/recover as above; the hang was a real transient failure, not a landed-but-unreported merge.

---

## Pre-flight: colliding open PR on a shared file

Before committing a change to a file that's shared and frequently touched across sessions (`.claude/settings.json` is the recurring offender in this repo), check for an existing open PR against it first — a distinct problem from general concurrent-session detection, which only detects that _another_ session exists, not that it's about to make a colliding edit to a specific file. Check command and rationale: [references/shared-file-collision-preflight.md](references/shared-file-collision-preflight.md).

---

## Post-merge issue verification

See also the mandatory pre-merge check in the callout near the top of this file — it catches a malformed multi-issue `Closes` clause right after PR creation, before merge. This section is the backstop: after merging a PR whose `## Refs` section claims to close one or more issues, verify each one actually closed — GitHub's auto-close is silent on failure, so a malformed keyword (comma-list, typo'd number, wrong repo) leaves an issue open with no error anywhere.

```bash
bash ~/.claude/skills/git-ops/scripts/verify-closes.sh <pr-number> [owner/repo]
```

Prints `CLOSED:<N>` / `OPEN:<N>` / `ERROR:<N>` per referenced issue and exits non-zero if any didn't close — replaces hand-writing the same `for n in ...` loop after every merge. Full background on why this matters and what to do with an `OPEN` result: [references/post-merge-verification.md](references/post-merge-verification.md).

---

## Multi-account operations

This environment often has more than one `gh` account active (e.g. a personal account and a work org account). Apply the checks below to **any mutating `gh` command** — not just `gh pr create` — since gh's active account can drift mid-session. Pre-flight commands, symptoms of account mismatch, and git-credential-helper fallbacks for stubborn push failures: [references/multi-account-operations.md](references/multi-account-operations.md).

---

## Pre-commit checks

Run checks **only on files you are modifying**. Do not run repo-wide formatters or linters as a side effect of an unrelated change — it pollutes the diff and steps on other people's in-flight work. Terraform fmt scoping, the configured-tool table for other languages, the shared-repo formatting rule, and the pre-commit-hook auto-fix recovery step: [references/pre-commit-checks.md](references/pre-commit-checks.md).

---

## Before pushing to an existing branch

Before every `git push` to a feature branch, check whether its PR is already merged — pushing to a merged branch orphans commits, and a three-dot diffstat is not reliable evidence of pending work after a squash-merge. Merged-PR check, squash-merge diffstat caveat, and CI/CD re-run behavior: [references/pushing-to-existing-branch.md](references/pushing-to-existing-branch.md).

**This check applies to every push in this session, not just the first one on a branch.** A branch whose PR merged earlier in this same session is exactly as merged as one merged in a prior session — a follow-up commit made right after a merge, before post-merge-cleanup has run, is the case most likely to get missed. Run the merged-PR check again immediately before pushing, even if you already ran it once for this branch earlier.

**Check PR history before force-deleting a branch name.** Before `git push --delete` or `git branch -D` on a branch that held real commits, list PRs for that head across all states (`gh pr list --head <branch> --state all`). If any PR exists (open/merged/closed) under that name, treat the name as historically reserved — prefer a differently-named branch for whatever comes next rather than deleting and immediately reusing the same name. A later real PR reusing a force-deleted branch name can collide with history the delete didn't actually clean up.

**Recovery recipe: merged branch + uncommitted new work on top.** A distinct case from the plain "don't push to an already-merged branch" one above — a second process left uncommitted new work in a shared (non-worktree) checkout, sitting on top of a branch whose PR has already merged. This isn't a simple commit+push, since the branch itself is dead weight now:

1. `git stash -u` (include untracked files — plain `git stash` misses them)
2. Check out a fresh branch off the current default branch (`git checkout main && git pull && git checkout -b <new-branch>`)
3. `git stash pop` to reapply the saved work, resolving any conflicts
4. Commit/push/PR as normal from the fresh branch

---

## Push immediately once a PR looks merge-ready

Once a merge conflict is resolved locally and the branch looks merge-ready, push right away — don't wait for session-close or a later checkpoint to do it. A PR merged via GitHub's web UI resolves conflicts against whatever is on the remote at that moment; a local-only commit that never got pushed (a separate fix made alongside the conflict resolution, say) is invisible to that merge and gets silently dropped, with no error anywhere — the merge just looks clean. Recovering it means noticing the gap after the fact and shipping a follow-up PR. Treat "conflicts resolved, ready to merge" as the trigger to push, not a state to sit in.

---

## Merge conflicts in generated/manifest-style files

A conflict in a file that's regenerated by a make target (e.g. `.deploy/repo-manifest.json`, regenerated by `make manifest-update`) should be resolved by taking either side, then regenerating via the repo's own generation command — never by hand-merging the diff. The generator is the source of truth for that file's exact shape; reconciling it by hand risks producing content the generator itself would never emit, and regenerating is cheap enough that there's no reason to try.

```bash
git checkout --ours .deploy/repo-manifest.json   # or --theirs — either is fine, it's about to be regenerated
make manifest-update
git add .deploy/repo-manifest.json
```

**⚠️ `git checkout <ref> -- <pathspec>` looks like the same safe idiom above but isn't.** `git checkout -- <file>` (no ref, restoring from the _current_ HEAD/index) is the safe, well-documented pattern used in the conflict-resolution case above and in session-close's own cleanup section. `git checkout <ref> -- <pathspec>` is a **different, cross-ref** command — it silently overwrites the working-tree contents of every matched file with `<ref>`'s version, discarding any uncommitted edits with no prompt. When the pathspec is `.` or a directory, this is **whole-tree**, not single-file. Before running any `git checkout <ref> -- ...` form, confirm `git status --short` is clean first, or use `git diff <ref> -- <pathspec>` to inspect what would change without applying it.

---

## Multi-commit same-file rebase conflicts

Rebasing a branch whose commits all touch a file that main has also changed conflicts at **every** replayed commit, not just once — each step re-introduces a conflict against the already-resolved state. Detect this before starting a rebase, and if detected, use a fresh branch off the updated default branch instead of fighting the rebase. Full detection commands and recovery steps: [references/rebase-conflicts.md](references/rebase-conflicts.md).

---

## Warn before checkout when uncommitted WIP exists

Before any `git checkout <branch>` (switching branches, not restoring a file), check `git status --short` first. If it's non-empty, stash or commit before switching — a bare checkout across branches with uncommitted changes present can drop them silently rather than erroring, and recovery then depends on the changes happening to exist elsewhere (a related branch, a stash entry) rather than being guaranteed. This matters most in multi-root workspaces with several concurrent feature branches, where a checkout to check something on another branch is easy to reach for without registering it as branch-switching.

---

## Multi-repo operations

When committing, pushing, or creating PRs across more than one repo in the same session, **run one Bash call per repo** — never batch cross-repo git operations as parallel tool calls, since parallel calls share working directory state and a `cd` in one can leak into another. Full rationale and which commands this applies to: [references/multi-repo-operations.md](references/multi-repo-operations.md).

---

## Recovering a cloud session with a broken Bash tool

A web/mobile (`claude.ai/code`) session that never ran `make install-system` can have every Bash call blocked by a `PreToolUse` hook referencing a missing `~/.claude/hooks/*.py` script — desktop sessions aren't affected, since Bash isn't broken there in the first place.

**Safe order of operations**: restore the hooks first, then use real `git`. Do not reach for a hand-retyped full-file push through the GitHub API (`mcp__github__push_files` or equivalent) as a first resort — it requires typing out the entire file's content as a string, which has silently dropped formatting-only content (italic markdown markers, on six unrelated lines) that the task never touched or intended to change. The regression wasn't caught until a manual diff against `main` after the fact ([PR #606](https://github.com/MichaelHeaton/ai-skills/pull/606)).

1. Read `.claude/settings.json` to find which hook scripts the blocked `PreToolUse` matcher references.
2. Locate their source under `ai/claude/hooks/` in the repo checkout.
3. Recreate them at `~/.claude/hooks/` using the **Write tool**, not Bash — Bash is what's blocked.
4. Once Bash unblocks, use real `git commit`/`git push` for the change, not the GitHub API.

**If hooks genuinely can't be restored** and an API push of _existing_ file content is unavoidable, diff the pushed result against the base branch before trusting it — specifically checking for formatting-only differences (italics, bold, etc.), since those are the easiest to drop unnoticed during manual retyping and the least likely to show up in a casual read-through.

---

## Worktree path safety when editing

**General principle**: whenever an isolated worktree session is active, verify any Edit/Write's resolved absolute path actually lands inside that worktree before writing — regardless of how the path was reached. A deployed skill symlink (below) is the most common way this drifts, but it's not the only one; a stale `cwd`, a wrong repo clone, or any plain absolute-path mistake typed or pasted without the worktree's prefix can produce the same failure, and none of those go through `~/.claude/skills/` at all. Before any such Edit/Write, `git -C "$(dirname <target-path>)" rev-parse --show-toplevel` and compare against the intended worktree root — full check and the motivating incident: [references/skill-symlink-safety.md](references/skill-symlink-safety.md).

`~/.claude/skills/<name>` is often a symlink into a repo's real checkout on disk — this is the special case. If a worktree branch is checked out for that same repo, an Edit/Write reached through the symlink path can resolve to the wrong on-disk location — e.g. the main checkout instead of the intended worktree. **Before an Edit/Write through a path under `~/.claude/skills/`**, resolve the symlink (`readlink -f`) and check for an active worktree on that repo (`git worktree list`) — full resolution commands and disambiguation rules when multiple worktrees exist: [references/skill-symlink-safety.md](references/skill-symlink-safety.md).

---

## Automated reminder hook (installed by default in this repo)

The rule "invoke git-ops on the first git commit/push/PR and every one after" (frontmatter, above) is easy to follow correctly from habit while never actually re-invoking the `Skill` tool — meaning its own freshness gate (AGENT.md check, humanizer pass) was never confirmed satisfied that session, even though the underlying git commands were run correctly by memory. Two companion hooks close this gap without blocking anything:

- `hooks/git-ops-track.py` (`PostToolUse`, matcher `Skill`) — records that git-ops fired, once per session
- `hooks/git-ops-reminder.py` (`PreToolUse`, matcher `Bash`) — prints a one-line nudge before a `git commit` / `git push` / `gh pr create` / `glab mr create` if git-ops hasn't fired yet this session

Both are advisory only (always exit 0, confirmed by reading both scripts) and never block a command.

**Installed by default in this repo (`ai-skills`)**: both hooks are wired into this repo's tracked `.claude/settings.json`, so any session working inside `ai-skills` gets the reminder automatically. **This gap had recurred more than once even with the hooks available and documented** (see ai-skills#330, #347) — the repeat cause was that "documented, opt-in" isn't the same as "on," so this repo now wires them by default rather than leaving that step to be remembered.

That default-on scope is limited to this repo's own checkouts — a PR here can't write to a user's live global `~/.claude/settings.json` (outside the repo, on Claude's own `Edit` deny-list — see `hooks/inline-bash-hooks.md`) or to any other repo's tracked settings. For any other repo where this reminder is wanted, add the same block via the `update-config` skill, routed to that repo's `.claude/settings.json` (or global, if it should apply everywhere):

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Skill", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/git-ops-track.py" }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/git-ops-reminder.py" }] }
    ]
  }
}
```

---

## PR-open staleness nudge (installed by default in this repo)

A separate, stateless hook fires the same "PR-open" moment for a different purpose: prompting a skill-staleness check instead of a git-ops re-invocation (ai-skills#470).

- `hooks/pr-open-staleness-nudge.py` (`PreToolUse`, matcher `Bash`) — prints a one-line nudge toward the `skill-staleness-check` skill before a `gh pr create` / `glab mr create` command, so local skill versions get compared against the claude.ai Skills store before the PR merges

It's advisory only (always exits 0) and never blocks PR creation. Unlike the git-ops reminder pair above, it has no companion tracker hook — it fires on every matching PR-open command regardless of whether `skill-staleness-check` already ran that session, since staleness can change between one PR and the next.

**Installed by default in this repo (`ai-skills`)**: wired into this repo's tracked `.claude/settings.json` alongside the other `PreToolUse`/`Bash` hooks. For any other repo where this nudge is wanted, add it via the `update-config` skill:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/pr-open-staleness-nudge.py" }] }
    ]
  }
}
```

---

## Scope discipline

This applies to all of the above: **fix what you touch, leave what you don't.**

- Don't refactor code outside your change's scope
- Don't fix typos or formatting in files you aren't otherwise modifying
- Don't reorganize imports or whitespace in unrelated files
- Don't add unrelated improvements "while you're in there"

If you notice something worth fixing outside your scope, create a ticket for it. Do the work separately.

**`make bootstrap-version` in this repo**: pass `SCOPE=<path>` (e.g. `make bootstrap-version SCOPE=ai/claude/skills/git-ops`) to normalize frontmatter on one skill/dir only — the unscoped form touches every skill in the repo and can pull unrelated whitespace churn into your diff. If you already ran the unscoped form and picked up unrelated changes, revert everything outside your actual scope before committing: `git diff --name-only | grep -v <your-path> | xargs git checkout --`.
