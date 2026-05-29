---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
---

# Branching conventions

## Work and team repos (employer GitHub, shared GitHub)

**Always branch + PR. Never push directly to main or master.**

Assume branch protection is enforced even when it isn't. Reasons:

- Team repos — a direct push affects others immediately
- Many have CI/CD on main; a bad push can break production
- PRs create a reviewable record; direct pushes do not

Pattern for every change, no matter how small:

1. Create a branch: `git checkout -b feat/PROJ-XXXXX-short-description` or `fix/...` or `docs/...`
2. Commit, push, open PR (or MR on GitLab)
3. Do not merge without at least checking if a reviewer is needed

Branch naming: follow whatever convention the repo already uses. Check recent branches with `git branch -r` before naming.

---

## Personal GitHub repos (ai-skills, personal KB, legacy claude-skills)

**Always branch + PR.** The review gate matters even when you are the only reviewer — it creates a record, forces a moment of reflection before merge, and keeps main stable.

Every change goes through a branch. The branch can be short-lived and self-merged, but it must exist.

### Why no direct-to-main exception

- **ai-skills** and your personal knowledge-base repo feed context to future agent sessions — a bad push to main affects the next session with no rollback gate
- "Trivial" is easy to misjudge; the cost of a branch is low, the cost of a bad main commit is not
- Consistency removes the judgment call

### Personal knowledge base — branch + PR, merge promptly

Repos that hold notes, tasks, and agent rules (markdown vaults, second-brain layouts) are the highest-risk personal repos. Content in an unmerged branch is invisible to the next session. The rule is branch + PR + **merge quickly** — not branch and leave open.

---

## GitLab repos

Follow the same rule as work repos — always branch + MR, never push to main. GitLab repos are team or shared repos by default.

---

## Summary table

| Repo type | Default | Direct to main? |
| --- | --- | --- |
| Employer / team GitHub | Branch + PR | Never |
| GitLab | Branch + MR | Never |
| Personal knowledge base | Branch + PR — merge promptly | Never |
| ai-skills | Branch + PR | Never |
| claude-skills (legacy) | Branch + PR | Never |
| Other personal | Branch + PR | Never |
