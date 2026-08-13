---
version: 1.3.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Multi-account operations

This environment often has more than one `gh` account active (e.g. a personal account and a work org account). Apply this section to **any mutating `gh` command** — not just `gh pr create`. That includes `gh pr create`, `gh pr edit`, `gh pr merge`, `gh issue create`, `gh issue edit`, `gh issue close`, and anything else that writes rather than reads.

**Always pass `--repo owner/repo` on any `gh` command against an org repo (e.g. `gh pr create`, `gh pr view`, `gh issue list`), and `--head branch-name` on top of that for `gh pr create`.** This isn't only an SSH-alias-remote workaround — an org repo's ambient git context (`cd`-resolved remote, active account) is more likely to disagree with the target repo than a personal one, so `gh` silently resolving the wrong repo from context is the more common failure mode for org work. Don't wait for a "must first push branch" or similar error before adding these flags; pass them from the first command.

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

**Symptoms of account mismatch** — all mean "fix the token/account, don't debug the remote":

- `GraphQL: Could not resolve to a Repository`
- `GraphQL: Unauthorized: As an Enterprise Managed User, ...`
- `GraphQL: Forbidden` — this one especially reads like a permissions or network problem, but it's usually the same account-mismatch (or a bad `GH_TOKEN` override) as the other two, not an outage. Recovery: run `gh auth status` to confirm the active account, switch to the correct one if it's wrong, and pass `--repo owner/repo` explicitly on the retry rather than relying on ambient context. If `gh auth status` shows an invalid or unexpected token, a stale `GH_TOKEN` exported earlier in the session is likely shadowing keyring auth — `unset GH_TOKEN` before retrying.

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

**If the push still fails even with a token-embedded URL**, the global `~/.gitconfig` likely has a `url.<...>.insteadOf` rule (common in multi-account setups that rewrite SSH remotes to HTTPS) rewriting the tokenized URL back to a bare one before the OS credential store (e.g. macOS Keychain) gets a chance to authenticate it with the wrong account's cached token. Bypass the global config entirely for this one command:

```bash
HOME=/tmp git -C <repo> \
  -c "url.https://<user>:<token>@github.com/.insteadOf=https://github.com/" \
  -c "credential.helper=" \
  push -u origin <branch>
```

`HOME=/tmp` prevents `~/.gitconfig`'s `insteadOf` rules from applying; `credential.helper=` disables the keychain lookup; the explicit `-c url....insteadOf` re-adds just the one rewrite this command needs, tokenized.

---

## `gh api`/`gh repo view` 404 on a repo that clearly exists

A repo returning 404 from `gh api repos/<owner>/<repo>` or `gh repo view` doesn't always mean the repo is missing or misnamed — if plain `git push`/`pull` over SSH already works against that same repo, the repo exists and network access is fine. The more likely cause is an SSO-authorization gap on the active token: an org that enforces SAML SSO requires each personal access token to be separately authorized for that org, and an unauthorized token gets a 404 rather than a 403 on API calls (GitHub's default behavior for SSO-gated resources, to avoid leaking their existence to unauthorized callers).

**Recovery**: authorize the token for the org's SSO (via the token settings page, or `gh auth refresh`), then retry. Don't spend time re-verifying the repo name or remote URL first — check SSO authorization before assuming the repo doesn't exist.

---

## Org scope — don't assume one org across repos

Account mismatch (above) isn't the only way a `gh` sweep across "all your repos" goes quiet-wrong. A team's repos can live across more than one GitHub org (or a personal org plus a personal-account namespace) even when a single `gh` account can see all of them — in that case there's no auth error at all, just a `gh pr list` or `gh search prs` sweep that silently comes back short because it only checked one org.

**Before treating any cross-repo PR/issue sweep as exhaustive**, check each repo's actual org from its own remote rather than assuming one org value applies to every repo in the set:

```bash
git -C <repo> remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#'
```

Group repos by the org this returns, and run the sweep once per org — a single `--owner <org>` or `--org <org>` filter carried over from one repo to the rest of the set is the failure mode, not the tool itself. This applies to `gh search prs`, `gh search issues`, and any hand-rolled "PRs across owned repos" loop alike.
