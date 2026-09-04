---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-04
updated_by: claude
name: memex-session-prune
description: Prune Memex vault session-close files (Outputs/Session/session-close-*.md) past the 14-day retention window — but only after mining the full text of the about-to-be-deleted batch, plus every previously-deleted file recoverable from git history, for friction or workarounds that recur across multiple sessions (delegates the scan to skill-review's corpus-audit variant). A recurring pattern is surfaced as a candidate skill fix or new skill idea before any file is deleted — the one place a single-session annoyance too low-signal for its own skill change becomes visible across sessions. Then deletes the stale batch, commits, and opens a PR in the memex repo matching prior retention-prune PRs. Use for "prune session-close files", "clean up old session summaries", "retention pass on session-close files", "run the session-close prune", or when memex's Outputs/Session directory has files older than 14 days awaiting cleanup.
compatibility: Requires git and gh CLI, with a local Memex checkout.
---

# Memex Session Prune

Deleting a stale session-close file destroys the one place a minor, single-session annoyance was ever written down. Before that happens, this skill checks whether the annoyance showed up more than once — across this batch and everything already pruned before it — since recurrence is the signal an individual session can't see on its own. Only after that check runs does the actual deletion happen.

**Resolving the vault path.** Use `$MEMEX_ROOT` for the vault location — resolve it once before touching anything:

```bash
MEMEX_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)"
[[ -d "$MEMEX_ROOT/Outputs/Session" ]] || MEMEX_ROOT=~/Projects/personal/memex
```

---

## 1. Check for unfinished prior work first

```bash
cd "$MEMEX_ROOT" && git status --porcelain -- Outputs/Session/
```

If session-close files already show as deleted-but-uncommitted, a prior session started this prune and didn't finish. Don't re-delete from disk — recover their content with `git show HEAD:<path>` and treat them as already identified for step 2, then continue from step 3.

## 2. Identify the prune batch

List session-close files and parse the date from the filename (`session-close-YYYY-MM-DD...`):

```bash
ls Outputs/Session/session-close-*.md
```

Cutoff = today minus 14 days. Batch = every file whose filename date is strictly older than the cutoff. If the batch is empty, report "no files past the 14-day cutoff" and stop — this skill is a delete-triggered safeguard, not a standalone audit (run `skill-review` directly for that).

## 3. Build the historical corpus — before deleting anything

1. **Read the full content** of every file in the prune batch.
2. **Recover every previously-pruned file** from git history — don't limit the corpus to this cycle's batch; go back as many prune cycles as history has:

   ```bash
   git log --diff-filter=D --name-only -- 'Outputs/Session/session-close-*.md'
   ```

   For each `<commit>`/`<path>` pair returned, the file's content immediately before deletion is at the parent commit:

   ```bash
   git show <commit>~1:<path>
   ```

3. Combine into one corpus: `{date, source path, full text}` for every file — current batch and all recovered history.

## 4. Run the corpus-audit pattern scan

Invoke `skill-review`'s corpus-audit variant _(global: ai-skills)_ over the full corpus from step 3 — see its [references/corpus-audit.md](../skill-review/references/corpus-audit.md) for the adapted SA1–SA4 procedure. Prefer the `skill-reviewer` sub-agent (skill-review's own sub-agent invocation pattern) since this corpus is typically larger than a single session's context.

Surface the result **before proceeding to step 5**:

- **Recurring pattern found** — same SA4 format (existing skill to improve / new skill idea), each citing ≥2 source files/dates as evidence. Offer to act now via `skill-create` or file a ticket in ai-skills, or defer.
- **Nothing recurs** — say so plainly ("no recurring pattern found across N files") and continue to step 5. Don't manufacture a finding to justify the scan.

## 5. Prune

Branch, commit, and PR mechanics follow `git-ops` _(global: ai-skills)_. Branch: `chore/prune-session-close-{YYYY-MM-DD}`.

```bash
git rm Outputs/Session/session-close-{file1} Outputs/Session/session-close-{file2}
git commit -m "$(cat <<'EOF'
chore(session): prune 14+ day-old session-close files ({oldest-date})

Routine retention prune, same pattern as prior session-close prune PRs
— these N summaries are past the 14-day retention window as of {today}.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push -u origin chore/prune-session-close-{YYYY-MM-DD}
gh pr create --repo "${GITHUB_PERSONAL_USER}/memex" --title "chore(session): prune 14+ day-old session-close files ({oldest-date})" --body "Routine retention prune — see commit message."
```

Never merge — owner reviews.

## 6. Report

```
✓ Corpus scan: N files (batch + recovered history) — <finding count> recurring pattern(s) [or: none found]
✓ Pruned: <list of files>
✓ PR: <url>
```
