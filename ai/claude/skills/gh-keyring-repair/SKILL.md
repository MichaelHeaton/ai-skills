---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
name: gh-keyring-repair
description: Diagnose and recover a broken macOS keyring backend for gh, distinct from a stale GH_TOKEN env var or a mismatched active account. Trigger when `gh auth token` returns empty or errors even though `gh auth status` reports logged in, when 401s persist despite the correct account being active, or when a fresh `unset GH_TOKEN` + `export GH_TOKEN=$(gh auth token ...)` still yields an empty value. Walks through `gh auth refresh` (falling back to `gh auth login` if refresh fails) and verifies the fix by re-running `gh auth token` before declaring it resolved. Not for wrong-account routing — see gh-account-routing for switching between valid, working accounts.
compatibility: macOS only — diagnoses the macOS Keychain-backed gh credential store. Requires gh CLI.
---

# GH Keyring Repair

A `gh` 401 or empty `gh auth token` can come from three unrelated causes that all look the same at first glance: a stale `GH_TOKEN` env var, the wrong account active, or the macOS keyring backend itself failing to release the stored credential. This skill diagnoses which one it is and, for the keyring case, walks through recovery and verifies it actually worked.

## 1. Distinguish the three failure modes

Run these checks in order — each one either resolves the failure or rules out a cause before moving to the next.

**(a) Stale `GH_TOKEN` env var already set.** Check first — it's the cheapest to rule out and the most common:

```bash
echo "GH_TOKEN is set: ${GH_TOKEN:+yes}"
```

If set, `unset GH_TOKEN` and retry the failing `gh` command. This is already documented in `gh-account-routing` Step 2 and `issue-update`'s account preflight — don't re-explain it here, just apply it and move on if it fixes the problem.

**(b) Wrong/mismatched active account.** If unsetting `GH_TOKEN` didn't fix it, check whether the active `gh` account matches the repo owner you're targeting:

```bash
gh auth status 2>&1 | grep "Logged in to github.com account"
```

If the active account is wrong for this repo, that's account routing, not a broken keyring — hand off to **`gh-account-routing`** (Steps 1-2) rather than continuing here. Don't duplicate its switch logic in this skill.

**(c) Broken keyring backend (this skill's actual case).** Only reach this once (a) and (b) are ruled out: the active account is correct, `GH_TOKEN` was freshly unset, and the failure persists. The signature:

```bash
gh auth status 2>&1
unset GH_TOKEN
gh auth token
```

`gh auth status` reports logged in (no error), but `gh auth token` returns empty output or an error — and this stays true even immediately after the `unset` above with no stale env var in play. That combination means the macOS Keychain item `gh` relies on isn't releasing the credential to the CLI, not a routing or env problem.

## 2. Recover the keyring

Start with a refresh — it re-establishes the credential without a full re-login:

```bash
gh auth refresh --hostname github.com
```

**If refresh itself fails or errors**, fall back to a full re-login:

```bash
gh auth login --hostname github.com --web
```

Follow the interactive/web prompts. This re-creates the Keychain item from scratch, which is the actual fix when the existing item is corrupted rather than merely expired.

## 3. Verify before declaring it resolved

**Don't assume the recovery command succeeding means the keyring is fixed** — `gh auth refresh`/`gh auth login` reporting success only means the auth flow completed, not that token retrieval now works. Re-run the exact check that surfaced the failure:

```bash
unset GH_TOKEN
export GH_TOKEN=$(gh auth token)
[[ -n "$GH_TOKEN" ]] && echo "recovered: token non-empty" || echo "still broken: token empty after refresh" >&2
```

If it's still empty, the keyring backend is still broken — don't loop on the same recovery command. Escalate: check `security find-generic-password -s "gh:github.com"` for the raw Keychain state, or consider `gh auth logout` followed by a clean `gh auth login` if refresh alone doesn't rebuild the item.

## Relationship to gh-account-routing

**`gh-account-routing`** handles switching between accounts that are individually *valid and working* — the credential exists and resolves fine, the only problem is which one is currently active. This skill handles a keyring backend that's *broken* — token retrieval fails regardless of which account is targeted, because the underlying macOS Keychain item itself won't release a credential.

The two are complementary, not overlapping:

- If switching accounts with `gh auth switch` still leaves every account unable to produce a token, that's this skill, not routing.
- If one specific account produces a token fine and the problem is just that the *wrong* one is active, that's `gh-account-routing`, not this skill.
- Run the diagnosis in Step 1 above before assuming which one applies — the two failure modes present almost identically as a generic 401.
