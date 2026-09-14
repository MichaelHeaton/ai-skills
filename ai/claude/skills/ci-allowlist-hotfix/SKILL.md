---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: ci-allowlist-hotfix
description: Recover from a GitHub Actions `workflow_dispatch` rejecting a needed input because its `type: choice` field has a fixed `options:` allowlist that excludes it — a 422 / "value is not included in the list" naming the input and its allowed values. Drafts the smallest one-file PR against the workflow YAML (widen `choice` to `string`, or add the missing option), then stops: no dispatch, and no live-ops action gated behind it, until that PR merges, since `workflow_dispatch` inputs are read from the target ref (usually the default branch) and an unmerged change isn't visible to a real dispatch call yet. Trigger on: `gh workflow run` or the dispatch API returning 422 with an allowed-values list; "value not in allowed list" on a dispatch; a node/resource left drained, cordoned, or SchedulingDisabled by a rejected follow-up dispatch; "workflow won't accept this input", "choice field too narrow". Not for other workflow failures (secrets, permissions, unrelated YAML errors) — that's ordinary CI debugging.
compatibility: Requires gh CLI (or equivalent Actions API access) and a repo where the target workflow YAML is editable via PR.
---

# CI Allowlist Hotfix

A `workflow_dispatch` input declared `type: choice` only accepts values in its `options:` list. When live ops needs a value that isn't on that list — mid-incident, with a resource already left in a half-finished state (drained, cordoned, paused) — the dispatch call fails with a 422 instead of running. This skill drafts the smallest fix and then stops, rather than trying to route around the restriction.

## 1. Recognize the failure signature

- `gh workflow run <workflow> -f <input>=<value>` (or the underlying Actions dispatch API call) returns a 422.
- The error names a specific input and lists its allowed values — e.g. `Invalid value for '<input>' ... allowed values: 'a', 'b', 'c'` — not a generic auth or permissions failure.
- The value being rejected is one the current live-ops task genuinely needs right now, not a typo.

If the 422 doesn't name an input plus an allowed-values list, this isn't an allowlist problem — treat it as ordinary CI debugging instead.

## 2. Stop and check for a stranded resource first

Before drafting anything, check whether the rejected dispatch was itself a follow-up step meant to undo or continue an earlier action (a drain, a cordon, a pause). If so, say so plainly — the resource is currently sitting in that intermediate state and will stay there until the input can be supplied. Don't let the hotfix drafting work proceed silently while that's left unstated.

## 3. Draft the smallest possible PR

Open the workflow YAML and make exactly one change, whichever is smaller:

- **Widen the type**: change `type: choice` to `type: string` on the affected input, and remove its now-unused `options:` block. This is usually the right call when the input is inherently open-ended (a `--limit` pattern, a hostname, a version string) and re-adding options as they come up isn't sustainable.
- **Add the option**: append the specific missing value to the existing `options:` list, leaving `type: choice` in place. Prefer this when the input is genuinely a closed set and this is a case of the set being incomplete rather than the wrong shape for a choice field.

Keep the diff to that one input, in that one file. This is an emergency hotfix, not an opportunity to also rename the input, add validation, or refactor nearby steps — those go in a follow-up ticket if warranted, not this PR.

Branch and PR per this repo's `git-ops` skill. Reference the triggering incident in the PR description if one exists, genericized to whatever the ticket itself already names — don't add internal details beyond that.

## 4. Explicit stop — do not dispatch on the unmerged branch

**Do not attempt the actual mutating dispatch, or any other live-ops action gated behind this input, until the hotfix PR is merged.**

State this as a hard stop, not a caution buried at the end: GitHub Actions reads `workflow_dispatch` inputs (including a `choice` input's `options:` list) from the workflow file as it exists on the target ref — normally the repository's default branch — at dispatch time. A workflow YAML change that only exists on an unmerged feature branch is not visible to a real dispatch call against the default branch, so trying to dispatch before merge fails with the exact same 422, not a partial or best-effort success.

Tell the operator plainly:

- The PR is drafted and ready for review — link it.
- The blocked live-ops step (and the resource it's blocked on, e.g. a SchedulingDisabled node) stays in its current state until the PR merges.
- Once merged, re-run the original dispatch — it will now see the updated `options:` list or the widened `string` type.

## 5. After merge

Once the PR is merged, resume the original live-ops task: re-run the dispatch with the previously-rejected value, then proceed with whatever the dispatch was gating (uncordoning a node, continuing a run, etc.). Don't re-derive the original plan from scratch — pick back up where the 422 interrupted it.
