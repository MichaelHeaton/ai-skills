---
version: 1.4.0
principles_version: 1.0.0
last_updated: 2026-09-01
updated_by: claude
name: contextual-pr-review
description: Review a GitHub PR — your own or a teammate's — by first loading the target repo's own conventions (CLAUDE.md/AGENTS.md, sibling directories with the same structural pattern) so the review checks the diff against real repo-specific rules instead of generic best practice. Always separates "what the PR does" from "findings"; checks the linked ticket's acceptance criteria and adds a verdict/open-questions section only when there's something real to report — sized to the diff, not a fixed template. Use for "review this PR", "look over PR #N", "<name> asked for a review on <url>", a bare PR URL, or before eyeballing a diff casually and trusting the author's own testing. Works for any repo, including GitHub Enterprise hosts (auto-detects GH_HOST from the remote) — deliberately non-Vault-scoped. Prefer this over /code-review for a bare "review PR #N"; pick /code-review when an effort level or --comment/--fix flag is named, or the target is a diff/branch/path rather than a PR.
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

## 5. Check the ticket's acceptance criteria — only as far as there's something to check

A PR description restating its own intent isn't the same as verifying it against the ticket that spawned it. Find the linked ticket, but scale what you do next to what's actually there — don't force a full walkthrough of a null result:

- **Jira**: look for a key pattern like `PROJ-12345` in the PR body, title, or branch name (often rendered as a link, e.g. `[Jira: CESSS-16343](...)`). Fetch it with the Atlassian MCP (`jira_get_issue`) if connected, otherwise open the link.
- **GitHub Issues**: look for `Closes #N` / `Fixes #N` / `Resolves #N` in the PR body, or a bare `#N`. Fetch with `gh issue view <n> --repo <owner/repo>`.
- **No ticket linked anywhere** — say so in one sentence in the report. Nothing further to fetch or check.
- **Ticket linked but has no concrete, checkable AC** (just a description or a paragraph, no specific values/thresholds/flags) — say so in one sentence. Don't manufacture a walkthrough of criteria that don't exist — this is the common case, not the exception (the PR that prompted this step, CESSS-16343, was exactly this: a Jira link with no bulleted AC).
- **Ticket has concrete AC** — dispatch the `ac-conformance-check` skill to diff those AC items against the actual diff, rather than re-deriving the same extract/map/verify logic here. Fold its result into the report as a couple of sentences: which AC items matched, which didn't.

## 6. Report sized to the diff, not to a template

Two things always belong in the report, regardless of PR size — this is the actual fix for what went wrong in the review that prompted this skill's AC-check step (a write-up that blended "what changed" into "findings" and buried a good open question):

1. **What this PR does** — a plain-language summary grounded in the actual diff, not a restatement of the PR title or description.
2. **Findings** — substantive issues, ranked by severity, most severe first. Say plainly if a finding is inherited from existing code rather than introduced by this PR — that changes the urgency, not whether it's worth mentioning. If nothing of substance survives scrutiny, say that plainly instead of padding the list to look thorough.

Everything else scales with the diff — don't force a labeled section for a null result:

- **Small, single-purpose diffs**: fold the ticket status (step 5) and a verdict into a couple of sentences. Skip a separate "open questions" section if there's nothing to ask.
- **Larger or logic-bearing diffs**: give AC-check its own paragraph, state a clear verdict (ship, hold, or discuss — not a hedge), and list any open questions for the author that aren't blocking findings (e.g. "is this default intentional, or an oversight?") — distinct from a defect in the findings, since it's a judgment call the author made on purpose that can't be verified from the diff alone.

## 7. Offer — don't silently open — a follow-up fix

If a finding is something fixable in a repo you can push to yourself (not just something to flag to the PR's author), offer to open a real follow-up PR for it rather than only reporting it and waiting. This is often more useful than a comment that sits unread. But **ask before opening it** — a new PR is visible to teammates and affects shared state, so confirm first rather than auto-creating it as part of the review. Use the `git-ops` skill for the branch/commit/PR mechanics once confirmed.

## What this skill doesn't do

- It doesn't replace `/code-review`'s actual line-by-line analysis — for the large-diff case, that work happens inside the dispatched `reviewer` subagent (or `/code-review` itself, if you prefer its `--comment`/`--fix` options over a subagent).
- It isn't for reviewing `terraform plan`/`apply` output — that's `iac-reviewer`'s job (a different input shape: plan JSON, not a source diff).
