---
version: 1.7.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
name: git-ops
description: Universal git hygiene guide — fires on any git commit, push, PR, or MR operation in any repo. Covers branching rules, commit message format, PR/MR description format, and pre-commit checks scoped to modified files (including terraform fmt). Applies regardless of which other skills are active. Trigger on: any request to commit, push, open a PR or MR, "git commit", "create a PR", "push this", "open a pull request", "submit a MR", "ready to merge", or any variation of committing or sharing code changes.
---

Apply these rules for every git operation, in every repo. They complement repo-specific conventions — if a repo has its own stricter rules, follow those instead.

> **Non-negotiable before every `gh pr create` / `glab mr create`** — even when this skill is being applied from memory rather than freshly read:
>
> 1. **AGENT.md check** — see "Before opening a PR — AGENT.md check" below
> 2. **humanizer pass** on the PR Summary/Test plan — see "PR / MR descriptions" below
>
> Both are cheap (seconds) and both have been skipped in practice when the skill was recalled rather than re-invoked. If you're not certain these already ran this session, re-invoke the `Skill` tool on `git-ops` rather than proceeding from memory.

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

Before running `gh pr create`, invoke the `agent-md-sync` skill in check mode to verify that component-level AGENT.md files are up to date with the changes in this branch.

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
- Related PR: #NN (if any)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**Rules**

- Summary explains the *why*, not just the *what* — the diff shows the what
- Test plan must have at least one checkable item; "tested manually" is not enough
- Link the ticket; if there is no ticket, say so explicitly rather than omitting the section
- Keep the title short — details belong in the body
- **Before running `gh pr create` / `glab mr create`**, invoke the `humanizer` skill on the composed Summary and Test plan bullets — same "check before creation" pattern as the AGENT.md step above. Strips AI-writing tells while every fact, ticket ref, and checklist item survives unchanged.
- Always `cd` into the repo before running `gh pr create` — the `--repo` flag handles routing but `gh` still needs local git context to resolve the remote
- **SSH alias remotes**: if `origin` uses an SSH config alias (e.g. `git@github.com-personal:owner/repo`) rather than the literal `github.com` hostname, `gh pr create` may fail with "must first push branch" even when the branch is already pushed. **Default**: always pass `--repo owner/repo --head branch-name` — don't attempt without these flags first
- **Multi-account pre-flight**: see "Multi-account operations" below before running `gh pr create` on an org repo.

---

## Multi-account operations

This environment often has more than one `gh` account active (e.g. a personal account and a work org account). Apply this section to **any mutating `gh` command** — not just `gh pr create`. That includes `gh pr create`, `gh pr edit`, `gh pr merge`, `gh issue create`, `gh issue edit`, `gh issue close`, and anything else that writes rather than reads.

**Pre-flight — before the first mutating `gh` command on a repo**:

```bash
gh auth status
```

If the active account doesn't own the target repo, switch:

```bash
gh auth switch --user <account>
```

Or scope a single command without changing the active account:

```bash
GH_TOKEN=$(gh auth token --user <account>) gh pr create ...
```

**Symptoms of account mismatch** — both mean "fix the token/account, don't debug the remote":

- `GraphQL: Could not resolve to a Repository`
- `GraphQL: Unauthorized: As an Enterprise Managed User, ...`

**gh's active account can drift mid-session.** Don't assume it stays put after one `gh auth switch` — re-run `gh auth status` immediately before *every* mutating command, not just the first one in a session.

**Never run `gh auth switch` while a background polling/monitoring task is active against the same CLI.** `gh auth switch` mutates global CLI state shared across all concurrent shell sessions, not just the one it's run in — switching mid-poll can produce a false "terminal/complete" signal in a task that's actually still running against the wrong account's view of the repo. Either wait for the background task to finish first, or use the `GH_TOKEN=$(gh auth token --user <account>) gh ...` scoped form instead, which doesn't touch global state.

**Plain `git push`/`pull`/`fetch` are NOT governed by `gh`'s active account.** Over HTTPS, git's own `credential.helper` (often the OS keychain, e.g. `osxkeychain` on macOS) authenticates these commands — `gh auth switch` changes which account `gh` itself uses, but does nothing for plain git if the credential helper has a different cached credential. If `git push`/`pull`/`fetch` fails with an auth or "repository not found" error even after `gh auth switch` to the correct account, override the credential helper for that command:

```bash
git -c credential.helper= -c credential.helper="!gh auth git-credential" push origin <branch>
```

If that still doesn't resolve it, fall back to a token-embedded HTTPS remote URL for that one command:

```bash
git push "https://x-access-token:$(gh auth token --user <account>)@github.com/<owner>/<repo>.git" <branch>
```

---

## Pre-commit checks

Run checks **only on files you are modifying**. Do not run repo-wide formatters or linters as a side effect of an unrelated change — it pollutes the diff and steps on other people's in-flight work.

### Terraform

Before committing any `.tf` or `.tfvars` file:

```bash
# Format only the files in scope — not the whole repo
terraform fmt <file.tf>

# Or for a specific directory you own
terraform fmt <directory/>

# Never run this unless explicitly asked to clean up the whole repo
# terraform fmt -recursive
```

Check first with `terraform fmt -check <file>` to see if changes are needed before modifying. If the repo has a CI check that enforces fmt, fix it now rather than letting CI fail.

**The shared-repo rule**: If you're making a targeted change in a team repo and you notice other files are unformatted (e.g. from a teammate's recent commit), do *not* fix them in your PR. Flag it in a comment or a separate issue. Mixing formatting fixes with functional changes makes reviews harder and can conflict with in-flight work.

### Other languages and tools

Only run formatters/linters that are already configured in the repo. Check before running:

| Tool | Config signal | Scope |
| --- | --- | --- |
| `black` / `ruff` | `pyproject.toml`, `.ruff.toml`, `setup.cfg` | Modified `.py` files only |
| `shellcheck` | CI config, `Makefile` | Modified `.sh` files only |
| `yamllint` | `.yamllint`, CI config | Modified `.yml`/`.yaml` files only |
| `prettier` | `.prettierrc`, `package.json` | Modified files only |

If no config exists for a tool, do not run it. Do not install or introduce new formatters without asking.

### Before every commit — quick checklist

- [ ] No secrets, tokens, or credentials in staged files
- [ ] No debug output, `console.log`, or `print` left in production paths
- [ ] Commit message follows conventional format with ticket ref if applicable
- [ ] Pre-commit checks run on modified files
- [ ] Branch name matches repo convention (check recent branches if unsure)

---

## Before pushing to an existing branch

Before every `git push` to a feature branch, check whether its PR is already merged:

```bash
export GH_TOKEN=$(gh auth token --user "${GH_PERSONAL_USER}")
gh pr list --head <branch-name> --state merged --json number,title
```

- **Empty result (`[]`)** — PR is open or doesn't exist yet. Push normally.
- **Non-empty result** — PR is already merged. Do not push. Instead:
  1. Checkout the default branch and pull: `git checkout main && git pull`
  2. Create a new branch: `git checkout -b <descriptive-name>`
  3. Apply the pending changes (cherry-pick or re-apply)
  4. Push the new branch and open a new PR

Pushing to a merged branch orphans commits — they won't be in the default branch and require a cherry-pick recovery.

**A three-dot diffstat is not reliable evidence of pending work after a squash-merge.** `git diff origin/main...HEAD --stat` uses the merge-base at the point the branch diverged — but a squash-merge rewrites history and breaks that lineage, so the diffstat can show insertions/deletions that are already merged. Don't trust a non-empty `--stat` alone to mean "there's real pending work here." Verify with direct content comparison instead:

```bash
git diff origin/main..HEAD -- <file>   # two-dot: current tip vs current tip, not a stale merge-base
```

If that returns empty for every file the three-dot diffstat flagged, the branch's content is already merged — treat it the same as the "non-empty merged-PR check" case above, not as work to push.

### CI/CD behavior when pushing to an open PR

In repos where CI runs `plan` on PR push and `apply` on merge to main:

- Pushing to an open PR re-runs the **plan** check only — it does **not** trigger apply
- Apply only fires when the PR is **merged** to the default branch
- Never say "CI will re-run" in a way that implies apply will re-run — only the plan re-runs

---

## Multi-commit same-file rebase conflicts

Rebasing a branch whose commits all touch a file that main has also changed conflicts at **every** replayed commit, not just once — each step re-introduces a conflict against the already-resolved state. Detect this before starting a rebase, and if detected, use a fresh branch off the updated default branch instead of fighting the rebase. Full detection commands and recovery steps: [references/rebase-conflicts.md](references/rebase-conflicts.md).

---

## Multi-repo operations

When committing, pushing, or creating PRs across more than one repo in the same session, **run one Bash call per repo** — never batch cross-repo git operations as parallel tool calls.

**Why:** Parallel Bash calls share working directory state. A `cd` in one parallel call can leak into another, landing commits or PRs in the wrong repo or branch. Recovery requires rescue branches, hard resets, and re-runs — all avoidable.

```bash
# Safe — one call per repo, each with explicit cd
cd /path/to/repo-a && git add . && git commit -m "..."
# then separately:
cd /path/to/repo-b && git add . && git commit -m "..."

# Risky — parallel calls where CWD from one may bleed into another
# [never batch cross-repo git work in parallel]
```

This applies to: `git add`, `git commit`, `git push`, `gh pr create`, and any command whose behavior depends on CWD being a specific repo.

---

## Editing through a deployed skill symlink

**General principle**: whenever an isolated worktree session is active, verify any Edit/Write's resolved absolute path actually lands inside that worktree before writing — regardless of how the path was reached. A deployed skill symlink (below) is the most common way this drifts, but it's not the only one; a stale `cwd`, a wrong repo clone, or any other path-resolution mismatch can produce the same failure.

`~/.claude/skills/<name>` is often a symlink into a repo's real checkout on disk. If a worktree branch is checked out for that same repo, an Edit/Write reached through the symlink path can resolve to the wrong on-disk location — e.g. the main checkout instead of the intended worktree. **Before an Edit/Write through a path under `~/.claude/skills/`**, resolve the symlink (`readlink -f`) and check for an active worktree on that repo (`git worktree list`) — full resolution commands and disambiguation rules when multiple worktrees exist: [references/skill-symlink-safety.md](references/skill-symlink-safety.md).

---

## Scope discipline

This applies to all of the above: **fix what you touch, leave what you don't.**

- Don't refactor code outside your change's scope
- Don't fix typos or formatting in files you aren't otherwise modifying
- Don't reorganize imports or whitespace in unrelated files
- Don't add unrelated improvements "while you're in there"

If you notice something worth fixing outside your scope, create a ticket for it. Do the work separately.
