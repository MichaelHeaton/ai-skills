---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: review-tooling-coverage-audit
description: Pull the last N merged PRs for a repo, diff each against a fixed security/SRE/maintainability question set, and cross-check any gaps against what existing review tooling (skills, subagents, scanners) actually covers by re-reading its real source — not by assuming coverage from a name or description. Emits a gap table and a recommendation on whether new dedicated review tooling is warranted, or whether existing tooling plus deterministic checks already cover the ground. Use when deciding whether a pipeline (like dev-team) needs a new dedicated review role, when asked "do we actually need X reviewer" or "what review gaps do we have", or during periodic tooling-coverage checks.
compatibility: Requires gh CLI or equivalent PR access, and read access to the repo's existing review tooling definitions.
---

# Review Tooling Coverage Audit

Deciding whether to add a new dedicated reviewer (a security agent, an SRE agent) is easy to get wrong in both directions: adding tooling that duplicates what already exists, or skipping tooling because something with a plausible-sounding name is assumed to cover the gap without checking. This skill replaces the assumption with a mechanical check.

## 1. Pull recent history

Fetch the last N (default 15–20) merged PRs for the repo in scope:

```bash
gh pr list --repo <owner/repo> --state merged --limit 20 --json number,title,files
```

## 2. Apply the fixed question set

For each PR, check it against a fixed set of security/SRE/maintainability questions — not a bespoke list re-derived per audit:

- Did any secret, credential, or token pattern appear in the diff?
- Did any destructive operation (delete, drop, force-push equivalent) ship without an explicit safeguard?
- Did any config value contradict a documented convention or a linked ticket's stated requirement?
- Did the diff change error-handling or retry behavior without a corresponding test?
- Did the diff touch a shared/high-blast-radius file without the collision check this repo's tooling documents?

Record which PRs would have tripped which question, whether or not something actually caught it at the time.

## 3. Cross-check against real tooling scope

For each question that found a hit (or a near-miss), read the **actual source** of the review tooling that's supposed to cover it — the subagent's real prompt, the skill's real SKILL.md, the scanner's real config — rather than assuming a plausibly-named tool ("SecurityReview") covers a given question. Tooling can exist and still not actually check the thing being audited.

## 4. Emit the gap table and verdict

```
| Question | Hits in last 20 PRs | Tooling claiming coverage | Actually covers it? |
| --- | --- | --- | --- |
| Secret in diff | 0 | secret-scan hook | Yes — verified in hook source |
| Config vs. ticket AC | 2 | none | No — recommend ac-conformance-check |
| Destructive op unguarded | 1 | iac-reviewer subagent | Partial — only Terraform, not raw kubectl |
```

**Recommendation**: state plainly whether the gap warrants new dedicated review tooling/roles, or whether a deterministic check (a hook, a lint rule) is sufficient and lighter-weight than a new agent. Default toward the deterministic option when the gap is mechanically checkable — reserve new dedicated reviewer roles for gaps that genuinely need judgment, not pattern-matching.
