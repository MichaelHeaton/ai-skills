---
version: 1.1.1
principles_version: 1.0.0
last_updated: 2026-09-23
updated_by: claude
name: post-merge-cleanup
description: Clean up after a PR merges — pull main, remove the worktree, delete the local (and remote-if-needed) feature branch, and run the repo's redeploy/build step — without requiring a full session-close run. Use whenever the user says "that PR merged", "merged, can you clean up", "PR's in, sync main", or right after confirming a merge via gh/glab, in any repo. For end-of-session hygiene across multiple repos, use session-close instead — this skill is the single-repo, single-PR version of the same sequence.
compatibility: Cloud-compatible — no local-machine-only paths or tooling; step 4's redeploy detection just skips silently where nothing applies. Requires git; gh or glab for remote branch state.
---

# Post-Merge Cleanup

The four-step sequence every merged PR needs, as a skill instead of prose duplicated per-repo in CLAUDE.md files. Portable — nothing here assumes `make install-system` or any other ai-skills-specific tooling.

## When push or PR creation is handed off to the user

Auto-trigger on "that PR merged" depends on the agent having actually observed the PR get created — if a push or PR creation gets handed off instead (a blocked local git tool, a Cursor hook, or any other reason the agent couldn't do it directly), explicitly prompt the user before ending that turn: *"I couldn't push/open this PR myself — once you've merged it, let me know so I can run this cleanup."* Without that prompt, the merge happens with no observed PR to trigger on, and cleanup never auto-fires.

No change to the happy path — when the agent itself opens the PR, auto-trigger on merge confirmation works as before.

## When multiple PRs merge close together in the same repo

Complete the full cleanup sequence (pull-main through redeploy) for the first merge before making any new commit in that repo — don't start on the second PR's follow-up work while the first is only partially cleaned up. A commit made between "first PR merged" and "first PR's cleanup finished" risks landing on a branch whose PR just merged, producing an avoidable conflict PR. Process merges in the order they landed, one full cleanup at a time.

**This is the default for two merges landing close together.** For a longer run of same-repo merges — three or more, or whenever the user explicitly signals batch processing — see "Burst/batch mode" below instead. It changes this rule's don't-start-the-next-commit-before-cleanup-finishes guarantee only for the expensive Step 4/5 checks; Steps 1–3 still run after every merge, in order, exactly as described here.

## Burst/batch mode (rapid same-repo multi-PR merges)

When several PRs merge back-to-back in the same repo within one session — a deliberate multi-PR run, not the occasional close-together pair covered above — running Step 4 (redeploy) and Step 5 (Actions check) after every single merge re-checks a state that's about to change again within minutes. Burst mode defers those two steps to the end of the batch while still keeping main and local git state in sync after every merge.

**Signal to enter burst mode** — either is sufficient:

- The user says so explicitly ("processing N PRs in a row," "burst mode," "batch-merging these")
- Three or more PRs have been confirmed merged in the same repo within this session, with more still queued

**Intermediate merges** (any merge that isn't the last in the batch) — run only:

1. Pull main (fast-forward)
2. Remove the worktree (if one was used)
3. Delete the local (and remote, if needed) branch

Skip Step 4 and Step 5 for every intermediate merge — do not redeploy or check Actions after each one.

**Burst end** (the last merge in the batch, or the burst is explicitly declared over) — run the full sequence: Steps 1–3 as above, plus:

- Step 4 — Redeploy / rebuild
- Step 5 — Check the latest Actions run on the default branch

**Single-PR / non-burst path is unchanged.** Outside a declared or detected burst, every merge still runs the full five-step sequence immediately, per the default described above.

### Failure modes

- **Burst abandoned mid-way** (session ends, or the remaining queued PRs never land) — the last intermediate merge's skipped Step 4/5 is still pending, not waived. Run the full Step 4 + Step 5 pass before ending the session, or before starting unrelated work in this repo, rather than letting a burst that never reached its declared end skip redeploy/Actions-check indefinitely.
- **Actions comes back red on the burst-end pass** — surface it the same way Step 5 already reports a single-merge failure, but call out explicitly that it may reflect any merge in the burst, not just the last one — none of the intermediate merges were checked individually, so isolating which one introduced the failure may require checking Actions runs for those commits after the fact.

## 1. Pull main (fast-forward)

```bash
git -C <repo> checkout main && git -C <repo> pull origin main
```

If the pull isn't a clean fast-forward, stop and surface it — that means main diverged in a way this cleanup shouldn't silently resolve.

## 2. Remove the worktree (if one was used)

```bash
git -C <repo> worktree list
```

If the merged branch had its own worktree, remove it:

```bash
git -C <repo> worktree remove <worktree-path>
```

Skip this step entirely if the work happened in the main checkout — not every merge involves a worktree.

**A `git worktree remove --force` can trigger Auto-review's smart-mode gate** — a safety checkpoint on high-velocity writes, not a failed command. It surfaces as a native approval card, not an error. Request approval via the card and continue (same pattern git-ops's batch-branch-delete note documents for `git branch -d`).

## 3. Delete the local (and remote, if needed) branch

```bash
git -C <repo> branch -d <branch-name>
```

`-d` only deletes fully-merged branches — if it refuses on a squash-merged branch (common; the squash commit's hash differs from the branch's original commits even though the content landed), verify the content actually landed before falling back to `-D`:

```bash
git -C <repo> log main --oneline | grep -F "<distinctive commit message text>"
```

**Remote branch**: skip deletion if GitHub/GitLab already auto-deleted it (check `gh pr view <n> --json headRepositoryOwner,headRefName` or the merge response) — don't assume it needs manual cleanup.

**A `git push --delete origin <branch>` can trigger Auto-review's smart-mode gate** — same safety checkpoint as the worktree-remove case above, not a failed command. It surfaces as a native approval card. Request approval via the card and continue.

**Misnamed-branch recovery via squash**: if session context shows the merged PR's tip was a recovery of commits that originally lived on a different, misnamed branch — later squashed into whatever branch actually merged — don't trust an empty `origin/main..<branch>` diff as proof nothing was stranded. A squash rewrites history, so that three-dot diff can read empty even when the recovered content never actually landed the way it was supposed to. This needs a more rigorous check than the commit-message grep above — a squash changes both the commit hash and message, so grepping for the original message won't reliably confirm the content landed:

```bash
git cherry main <branch>
git diff main -- <specific-file-that-mattered>
```

`git cherry` compares by patch-id, so it survives the squash rewrite and shows which commits from `<branch>` are genuinely not in `main` yet. Follow it with a scoped `git diff` of the specific files the recovery was supposed to bring over — not a full-tree diff — to confirm the content itself matches.

**If `git cherry` prints `+ <hash>` lines** (commits genuinely not in `main`), the recovery didn't fully land — don't delete the branch. Cherry-pick the missing commit(s) into a new branch off current `main` (`git cherry-pick <hash>`), open a follow-up PR for them, and flag the gap in your session summary so it isn't silently lost. Only proceed to branch deletion once `git cherry` shows nothing outstanding (every line prefixed `-`, meaning already in `main`).

## 4. Redeploy / rebuild (repo-appropriate)

This step is intentionally not hardcoded to any one command. Detect what the repo actually uses:

- `Makefile` with an `install`/`deploy`/`build` target → run it
- `package.json` with a `build`/`deploy` script → run it
- No such step documented → skip silently, nothing to redeploy

If unsure which command applies, ask once rather than guessing at a destructive or long-running build step.

## 5. Check the latest Actions run on the default branch

After syncing main, when the remote is GitHub and `gh` works: check whether the latest run on the default branch actually succeeded, rather than treating "main synced" as automatically clean.

```bash
gh run list --branch <default-branch> --limit 1 --json status,conclusion,name,url
```

A failing latest run belongs in the cleanup summary itself (workflow name + URL), not as a buried optional aside — a clean-looking sync can mask a broken production deploy. Skip silently when `gh` is unavailable, the remote isn't GitHub, or there's no recent run — same spirit as step 4's redeploy detection.

**Distinguish a `gh` network/timeout error from a real failed run before reporting anything.** `gh run list` (and `gh run watch` or a mid-poll `gh run view`, if either is used nearby) can exit non-zero on API i/o timeout — a `dial tcp ... i/o timeout`-style error connecting to `api.github.com` — even though the workflow it was checking already succeeded. That's a `gh`/network failure, not a workflow conclusion, and treating it at face value misreports a passing run as broken. If the `gh run list` call itself errors out this way, re-fetch once via `gh run view <run-id> --json conclusion,status,url` (or `gh run list --commit <sha>` if the run ID isn't known yet) before reporting anything. Treat a bare timeout as inconclusive, not red: don't print "✗ FAILED" in the Report section unless the retried call confirms a real failure. Report the retried result once it comes back — or, if the retry also times out, say so explicitly: "Actions check inconclusive (network timeout, not re-verified)".

**Distinguish a failing bot-generated PR from a real main-branch break before flagging it as a blocker.** A failing run on a bot/automation branch (`bot/`, `auto/`, `chore/*-regenerate`, or similar) that finished in a second or two with effectively zero jobs run is more likely an empty-job race in the bot's own PR than a break in what actually landed on main — log it as bot-PR noise rather than a cleanup blocker, as long as the run *on the default branch itself* is green. Still surface any real main-branch workflow failure at face value; this only applies to the bot-PR case, not to a genuine post-merge failure on main.

## Report

```
✓ main synced (fast-forward)
✓ worktree removed
✓ local branch deleted (remote already auto-deleted)
✓ redeployed via `make install-system`
✓ latest Actions run on main: passed (or: ✗ FAILED — <workflow> <url>)
```

**In burst mode**, an intermediate merge's report omits the last two lines entirely rather than printing them as skipped — there's nothing to report on redeploy/Actions until the burst-end pass runs them:

```
✓ main synced (fast-forward)
✓ worktree removed
✓ local branch deleted (remote already auto-deleted)
— redeploy and Actions check deferred to burst end
```
