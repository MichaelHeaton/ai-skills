---
version: 1.17.0
principles_version: 1.0.0
last_updated: 2026-08-14
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
- Co-author line when Claude wrote the commit: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
- One logical change per commit — don't bundle unrelated fixes

**Examples**

```
feat(session-close): add skill hygiene review step

Closes: #28
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
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

## Shared checkout branch-identity check

Distinct from `session-close`'s concurrent-session check, which only answers "does another live process exist?" — it doesn't catch a second process **sharing this exact (non-worktree) checkout** silently swapping the active branch out from under this session. An isolated `git worktree` checkout is immune to this (its branch is pinned to that worktree); a shared/main checkout is not — a background task checking out its own branch directly in a shared working directory can silently replace the branch this session believes it's still on, and a commit can land on the wrong branch before anyone notices.

Before every `git commit`, verify the active branch is still the one this session expects (the branch named in the Architect/plan step, or the branch you last explicitly checked out or created):

```bash
bash ~/.claude/skills/git-ops/scripts/check-branch-identity.sh <repo-path> <expected-branch>
```

- **`MATCH`** — proceed
- **`WORKTREE:<actual>`** — this checkout is an isolated worktree; a branch swap in a _different_ checkout of the same repo can't collide with it here. Proceed.
- **`MISMATCH:<actual>`** — the active branch changed unexpectedly in a shared checkout. **Stop before committing.** Confirm which branch is actually correct before proceeding — do not commit onto whatever happens to be checked out.

---

## Live concurrent-session detection

Distinct from the "Shared checkout branch-identity check" above, which only catches a branch swap _after_ it's already happened. Before committing, check whether a second Claude Code session is actively writing to this same repo right now — via `ps aux` for another process with `--add-dir` on this repo, plus a file-mtime check against this session's own start time. Full detection commands and the "don't touch the other session's in-progress edit; move to a fresh branch off updated main once it's done" recovery: [references/live-concurrent-session.md](references/live-concurrent-session.md).

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

---

## Pre-flight: colliding open PR on a shared file

Before committing a change to a file that's shared and frequently touched across sessions (`.claude/settings.json` is the recurring offender in this repo), check for an existing open PR against it first — a distinct problem from general concurrent-session detection, which only detects that _another_ session exists, not that it's about to make a colliding edit to a specific file. Check command and rationale: [references/shared-file-collision-preflight.md](references/shared-file-collision-preflight.md).

---

## Post-merge issue verification

After merging a PR whose `## Refs` section claims to close one or more issues, verify each one actually closed — GitHub's auto-close is silent on failure, so a malformed keyword (comma-list, typo'd number, wrong repo) leaves an issue open with no error anywhere.

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

---

## Push immediately once a PR looks merge-ready

Once a merge conflict is resolved locally and the branch looks merge-ready, push right away — don't wait for session-close or a later checkpoint to do it. A PR merged via GitHub's web UI resolves conflicts against whatever is on the remote at that moment; a local-only commit that never got pushed (a separate fix made alongside the conflict resolution, say) is invisible to that merge and gets silently dropped, with no error anywhere — the merge just looks clean. Recovering it means noticing the gap after the fact and shipping a follow-up PR. Treat "conflicts resolved, ready to merge" as the trigger to push, not a state to sit in.

---

## Multi-commit same-file rebase conflicts

Rebasing a branch whose commits all touch a file that main has also changed conflicts at **every** replayed commit, not just once — each step re-introduces a conflict against the already-resolved state. Detect this before starting a rebase, and if detected, use a fresh branch off the updated default branch instead of fighting the rebase. Full detection commands and recovery steps: [references/rebase-conflicts.md](references/rebase-conflicts.md).

---

## Multi-repo operations

When committing, pushing, or creating PRs across more than one repo in the same session, **run one Bash call per repo** — never batch cross-repo git operations as parallel tool calls, since parallel calls share working directory state and a `cd` in one can leak into another. Full rationale and which commands this applies to: [references/multi-repo-operations.md](references/multi-repo-operations.md).

---

## Worktree path safety when editing

**General principle**: whenever an isolated worktree session is active, verify any Edit/Write's resolved absolute path actually lands inside that worktree before writing — regardless of how the path was reached. A deployed skill symlink (below) is the most common way this drifts, but it's not the only one; a stale `cwd`, a wrong repo clone, or any plain absolute-path mistake typed or pasted without the worktree's prefix can produce the same failure, and none of those go through `~/.claude/skills/` at all. Before any such Edit/Write, `git -C "$(dirname <target-path>)" rev-parse --show-toplevel` and compare against the intended worktree root — full check and the motivating incident: [references/skill-symlink-safety.md](references/skill-symlink-safety.md).

`~/.claude/skills/<name>` is often a symlink into a repo's real checkout on disk — this is the special case. If a worktree branch is checked out for that same repo, an Edit/Write reached through the symlink path can resolve to the wrong on-disk location — e.g. the main checkout instead of the intended worktree. **Before an Edit/Write through a path under `~/.claude/skills/`**, resolve the symlink (`readlink -f`) and check for an active worktree on that repo (`git worktree list`) — full resolution commands and disambiguation rules when multiple worktrees exist: [references/skill-symlink-safety.md](references/skill-symlink-safety.md).

---

## Optional: automated reminder hook

The rule "invoke git-ops on the first git commit/push/PR and every one after" (frontmatter, above) is easy to follow correctly from habit while never actually re-invoking the `Skill` tool — meaning its own freshness gate (AGENT.md check, humanizer pass) was never confirmed satisfied that session, even though the underlying git commands were run correctly by memory. Two companion hooks close this gap without blocking anything:

- `hooks/git-ops-track.py` (`PostToolUse`, matcher `Skill`) — records that git-ops fired, once per session
- `hooks/git-ops-reminder.py` (`PreToolUse`, matcher `Bash`) — prints a one-line nudge before a `git commit` / `git push` / `gh pr create` / `glab mr create` if git-ops hasn't fired yet this session

Both are advisory only (always exit 0) and never block a command. They aren't wired into any tracked `settings.json` by default — add them via the `update-config` skill if you want the reminder:

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

## Scope discipline

This applies to all of the above: **fix what you touch, leave what you don't.**

- Don't refactor code outside your change's scope
- Don't fix typos or formatting in files you aren't otherwise modifying
- Don't reorganize imports or whitespace in unrelated files
- Don't add unrelated improvements "while you're in there"

If you notice something worth fixing outside your scope, create a ticket for it. Do the work separately.

**`make bootstrap-version` in this repo**: pass `SCOPE=<path>` (e.g. `make bootstrap-version SCOPE=ai/claude/skills/git-ops`) to normalize frontmatter on one skill/dir only — the unscoped form touches every skill in the repo and can pull unrelated whitespace churn into your diff. If you already ran the unscoped form and picked up unrelated changes, revert everything outside your actual scope before committing: `git diff --name-only | grep -v <your-path> | xargs git checkout --`.
