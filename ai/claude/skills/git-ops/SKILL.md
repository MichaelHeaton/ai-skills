---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: git-ops
description: Universal git hygiene guide — fires on any git commit, push, PR, or MR operation in any repo. Covers branching rules, commit message format, PR/MR description format, and pre-commit checks scoped to modified files (including terraform fmt). Applies regardless of which other skills are active. Trigger on: any request to commit, push, open a PR or MR, "git commit", "create a PR", "push this", "open a pull request", "submit a MR", "ready to merge", or any variation of committing or sharing code changes.
---





Apply these rules for every git operation, in every repo. They complement repo-specific conventions — if a repo has its own stricter rules, follow those instead.

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
- Always `cd` into the repo before running `gh pr create` — the `--repo` flag handles routing but `gh` still needs local git context to resolve the remote
- **SSH alias remotes**: if `origin` uses an SSH config alias (e.g. `git@github.com-personal:owner/repo`) rather than the literal `github.com` hostname, `gh pr create` fails with "must first push branch" even when the branch is already pushed. Fix: always pass `--repo owner/repo --head branch-name` to bypass alias resolution

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

### CI/CD behavior when pushing to an open PR

In repos where CI runs `plan` on PR push and `apply` on merge to main:

- Pushing to an open PR re-runs the **plan** check only — it does **not** trigger apply
- Apply only fires when the PR is **merged** to the default branch
- Never say "CI will re-run" in a way that implies apply will re-run — only the plan re-runs

---

## Scope discipline

This applies to all of the above: **fix what you touch, leave what you don't.**

- Don't refactor code outside your change's scope
- Don't fix typos or formatting in files you aren't otherwise modifying
- Don't reorganize imports or whitespace in unrelated files
- Don't add unrelated improvements "while you're in there"

If you notice something worth fixing outside your scope, create a ticket for it. Do the work separately.
