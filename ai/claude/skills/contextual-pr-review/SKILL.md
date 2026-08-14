---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: contextual-pr-review
description: Review a GitHub PR — your own or a teammate's — by first loading the target repo's own conventions (CLAUDE.md/AGENTS.md, sibling directories with the same structural pattern) so the review checks the diff against real repo-specific rules instead of generic best practice. Use for "review this PR", "look over PR #N", "<name> asked for a review on <url>", a bare PR URL, or before eyeballing a diff casually and trusting the author's own testing. Works for any repo, including GitHub Enterprise hosts (auto-detects GH_HOST from the remote) — deliberately non-Vault-scoped, though it grew out of Terraform module and per-cluster config repos. Prefer this over /code-review for a bare "review PR #N" with no flags; pick /code-review when the request names an effort level or a --comment/--fix flag, or targets a diff/branch/path rather than a PR. Complements /code-review (repo-agnostic, no context step) and the reviewer agent (dispatched for larger diffs, prompt front-loaded with context).
---

# Contextual PR Review

A PR review is only as good as what it's checked against. A generic "does this look right" pass misses the things that actually bite: a naming convention a downstream tool depends on, a capability grant that looks right but maps to no real API endpoint, a pattern every sibling workspace follows that this PR quietly breaks. This skill's job is to load that context *before* reviewing, then pick the right review mechanism for the size of the change.

## 1. Gather repo context first

Before looking at the diff:

- Read the target repo's `CLAUDE.md` and/or `AGENTS.md` if present. These usually document the naming conventions, gotchas, and security rules that generic review would miss.
- If the repo is one piece of a larger system (a module consumed by other repos, one of several workspaces following the same directory pattern), check whether related repos document conventions that apply here too — a module's own docs don't always repeat what the deploying repo's docs already say.
- Note anything that reads like a footgun: a type mismatch (e.g. a Terraform `set` vs `list`), a naming rule a downstream tool depends on, a "must stay scoped to X" security rule, a documented reason behind a setting that looks arbitrary out of context.

This step is what makes the review worth more than skimming — carry these specifics into whichever mechanism you use next.

## 2. Fetch the actual diff

Don't reconstruct a PR from memory or from what the title implies. Pull the real diff:

```
gh pr view <n> --repo <owner/repo>
gh pr diff <n> --repo <owner/repo>
```

**GitHub Enterprise remotes**: these calls default to `github.com` and fail with an opaque GraphQL repository-resolution error against an Enterprise host. Before the first `gh` call, check the repo's remote and export `GH_HOST` if it isn't `github.com`:

```bash
url="$(git remote get-url origin)"
host="${url#*://}"      # strip scheme:// if present (https://, ssh://, git://)
host="${host#*@}"       # strip user@ if present (git@..., ssh://git@...)
GH_HOST="${host%%[:/]*}" # cut at first : or / — leaves just the hostname
[[ "$GH_HOST" == "github.com" ]] && unset GH_HOST || export GH_HOST
```

If the PR is already merged, diff the merge commit's own commits against their parent rather than assuming `main`'s current state matches what was reviewed.

## 3. Size-gate the review mechanism

- **Small, single-purpose diffs** (roughly a handful of lines, a config value, one file) — review directly in the current session. You already have the repo context loaded; spinning up a subagent for a 4-line diff just adds latency without adding rigor.
- **Larger or logic-bearing diffs** (new resources, new code paths, anything with its own tests) — dispatch to the `reviewer` subagent. Critically, **front-load its prompt with the repo-specific context from step 1** — the subagent starts with zero session memory, so a generic "review PR #23" prompt throws away everything you just learned. Include the specific gotchas, naming rules, and security invariants to check the diff against, not just a link to the PR.

There's no hard line-count threshold — the judgment call is whether the diff introduces new behavior worth reasoning about, or just changes a value/comment in an already-understood pattern.

## 4. Compare against sibling structure, not just history

Many repos in this ecosystem repeat the same directory shape across many near-identical instances (one directory per cluster, per workspace, per environment). For this class of repo, a change in one instance is worth diffing against its siblings, not just checked in isolation:

- Does this diff follow a pattern already established elsewhere? If not, is that a bug here, or something the siblings should adopt too?
- Does a companion file this instance has (or lacks) match what siblings have? A file that's empty, missing, or oddly named next to consistent siblings is worth asking the author about directly rather than assuming it's deliberate.

This step only applies when the repeated-directory pattern actually exists — don't force a sibling comparison in a repo that doesn't have one.

## 5. Report findings ranked by severity

Lead with the most severe finding. If a finding is inherited from existing code rather than introduced by this PR, say so — it changes the urgency, not whether it's worth mentioning. If nothing of substance survives scrutiny, say that plainly instead of padding the list to look thorough.

## 6. Offer — don't silently open — a follow-up fix

If a finding is something fixable in a repo you can push to yourself (not just something to flag to the PR's author), offer to open a real follow-up PR for it rather than only reporting it and waiting. This is often more useful than a comment that sits unread. But **ask before opening it** — a new PR is visible to teammates and affects shared state, so confirm first rather than auto-creating it as part of the review. Use the `git-ops` skill for the branch/commit/PR mechanics once confirmed.

## What this skill doesn't do

- It doesn't replace `/code-review`'s actual line-by-line analysis — for the large-diff case, that work happens inside the dispatched `reviewer` subagent (or `/code-review` itself, if you prefer its `--comment`/`--fix` options over a subagent).
- It isn't for reviewing `terraform plan`/`apply` output — that's `iac-reviewer`'s job (a different input shape: plan JSON, not a source diff).
