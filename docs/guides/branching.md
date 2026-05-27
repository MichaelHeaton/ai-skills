# Branching conventions

## Adobe repos (work and team repos)

**Always branch + PR. Never push directly to main or master.**

Assume branch protection is enforced even when it isn't. Reasons:
- Adobe repos are team repos — a direct push affects teammates immediately
- Many have CI/CD pipelines that trigger on main; a bad push can break production
- PRs create a reviewable record; direct pushes don't

Pattern for every change, no matter how small:
1. Create a branch: `git checkout -b feat/PROJ-XXXXX-short-description` or `fix/...` or `docs/...`
2. Commit, push, open PR
3. Do not merge without at least checking if a reviewer is needed

Branch naming: follow whatever convention the repo already uses. Check recent branches with `git branch -r` before naming.

---

## Personal GitHub repos (memex, claude-skills, etc.)

**Always branch + PR.** The review gate matters even when you're the only reviewer — it creates a record, forces a moment of reflection before merge, and keeps main stable.

The carve-out for "trivial direct pushes" is removed. Every change goes through a branch. The branch can be short-lived and self-merged, but it must exist.

### Why no direct-to-main exception
- claude-skills and Memex both feed context to future Claude sessions — a bad push to main immediately affects the next session with no rollback gate
- "Trivial" is easy to misjudge in the moment; the cost of a branch is low, the cost of a bad main commit is not
- Consistency removes the judgment call — always branch means never second-guessing

### Memex — branch + PR, merge promptly
Memex is the highest-risk repo. Content in an unmerged branch is invisible to the next session. The rule is branch + PR + merge quickly — not branch and leave open. A PR that sits unmerged creates the context-isolation problem session-close is designed to detect.

---

## GitLab repos

Follow the same rule as Adobe repos — always branch + MR, never push to main. GitLab repos are team or shared repos by default.

---

## Summary table

| Repo type | Default | Direct to main? |
|---|---|---|
| Adobe GitHub | Branch + PR | Never |
| GitLab | Branch + MR | Never |
| Memex | Branch + PR — merge promptly | Never |
| claude-skills | Branch + PR | Never |
| Other personal | Branch + PR | Never |
