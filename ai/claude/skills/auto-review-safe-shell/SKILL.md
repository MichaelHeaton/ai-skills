---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: auto-review-safe-shell
description: Split a multi-step credential-then-mutation shell sequence (export a token, then separately run a mutating command that relies on it) into separate Bash tool calls with an explicit non-empty check in between. If the export step is blocked, denied, or silently fails, a downstream mutating command in the same block can still appear to run against an empty or stale credential, with no gate catching it. Use when constructing a shell call that resolves a credential then separately mutates with it, when a combined block gets blocked, or when asked "why did my command get blocked", "how do I avoid a silent stale-credential mutation", "split this into safe blocks". Concrete existing instance: issue-create's GH_TOKEN-export split. Distinct from git-ops's single-invocation scoped form (`GH_TOKEN=$(...) gh ...`), which has no step boundary for a stale credential to hide behind.
compatibility: None — applies to any shell/tool-call construction regardless of repo or language.
---

# Auto-review safe shell

A shell block that resolves a credential in one step and then relies on it in a separate mutating step, all inside the same tool call, has a gap: if the credential step is blocked, denied, or approved-but-empty, the shell can still move on to the mutating step with no gate in between to catch it — the mutation then runs against a stale or empty credential, and it isn't obvious from the output alone that anything went wrong. This is a real, previously-observed failure mode (documented in `issue-create`), not a specific claim about how any one approval/safety gate scores risk — the fix holds regardless of which gate, if any, intervenes.

## The trigger

A single Bash tool invocation with **multiple sequential steps** where:

- **An earlier step** resolves a credential — `export GH_TOKEN=...`, `gh auth token`, `vault read`, reading a secret file, sourcing an env file with credentials in it
- **A later step in the same invocation** performs a mutating action relying on that credential — `gh issue create`, `git push`, `gh pr merge`, a `curl`/`gh api` write call, anything that changes state somewhere

The risk is specifically the **multi-step, unverified handoff** — export now, trust it later in the same block — not the mere presence of a credential and a mutation anywhere in the same command. See "Not the same as git-ops's scoped one-liner" below for the case that looks similar but isn't risky the same way.

## The safe pattern

Always split into two separate Bash tool calls:

1. **Block 1 — credential only.** Export or resolve the credential and verify it's actually non-empty. Nothing mutating happens here.

   ```bash
   export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER}")
   [[ -n "$GH_TOKEN" ]] && echo "token set" || echo "token EMPTY"
   ```

2. **Block 2 — mutation only.** Perform the actual write, using the already-exported value from block 1 (the shell's working directory and environment persist between calls in this environment, so the export carries over).

   ```bash
   gh issue create --repo <owner/repo> --title "<title>" --body "<body>"
   ```

Resist the "one command is simpler" instinct — the two-block split is the whole point. A merged block that happens to work once doesn't mean it's safe; it means Auto-review didn't happen to fire that time.

## Failure mode to watch for

If block 1 is blocked or denied, **do not assume block 2 ran** just because the sequence looked like it executed end to end. A blocked credential step means the mutation in block 2 either didn't run or ran against an empty/stale credential.

Before trusting a downstream mutation succeeded:

- Confirm block 1's non-empty check actually printed a success line — don't infer success from the absence of an error.
- If block 1 was blocked or denied, re-run it, confirm the credential lands, and only then re-run block 2 — never re-run block 2 alone on the assumption that the credential from an earlier, uncertain attempt is still good.

## Precedent this generalizes

This is not a new rule invented in the abstract — it generalizes a pattern `issue-create` already documents for one specific case: "Never combine `export GH_TOKEN=...` (or any credential lookup) with `gh issue create` or another mutating `gh` call in the same shell invocation," with the same re-attempt-don't-assume guidance for a blocked export. `issue-create` should cross-link here as the general reference; that's tracked as separate follow-up work, not part of this skill's own file.

## Not the same as git-ops's scoped one-liner

`git-ops`'s multi-account guidance recommends the *opposite* of splitting in one specific case: `GH_TOKEN=$(gh auth token --user <account>) gh pr create ...` as a single command, preferred over `gh auth switch` precisely because it avoids mutating global CLI auth state. This does not contradict the rule above — it's a different shape entirely:

- **git-ops's scoped form is one atomic command.** The credential resolution and the mutation live or die together — if `gh auth token` fails, the whole command fails immediately, with no intervening step where the shell could move on to the mutation with stale or empty credential state. There's no unverified handoff to go wrong.
- **This skill's trigger is a multi-step sequence** — an earlier step exports/resolves the credential and *finishes*, then a later, separate step in the same block trusts that the export succeeded. That gap between steps is where a blocked or silently-failed export can leave a stale value for the mutation to use unnoticed.

Test: if resolving the credential and performing the mutation are one command with no step boundary between them, it's git-ops's safe scoped form, not this skill's risk shape. If there's a step boundary — a completed export, then a separate command that assumes it worked — split them per this skill.

## Applies beyond GitHub

The same split applies to any credential-then-mutation shape, not just `gh`:

- `vault read secret/foo` → then a mutating call using the fetched value
- Reading a cloud provider's short-lived STS/session token → then a `terraform apply` or write API call
- Sourcing a `.env` file with an API key → then a `curl -X POST` using that key

The credential mechanism changes; the split-block discipline doesn't.
