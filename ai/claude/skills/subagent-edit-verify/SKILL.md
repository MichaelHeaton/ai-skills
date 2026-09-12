---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: subagent-edit-verify
description: Immediately diff a background agent's reported file writes/edits against actual current git state — right after the completion report, not deferred to session-close — to catch concurrent-checkout clobbering or other silent loss. Triggers whenever any background Agent (generic subagent spawn, dev-team-coder, or otherwise) reports writing or editing a file, before trusting that report as durable. Generalizes dev-team-manager's "verify Coder's report against actual repo state (git status --short, git log main..HEAD --oneline)" into a standalone check for any orchestrator. Use on "did that edit actually land", "verify the agent's file changes", "the agent said it wrote X but I want to confirm", or right after any Agent-tool completion claiming a write/edit. Complements subagent-completion-verify (confirms the agent finished at all) — this confirms claimed content matches disk. On mismatch, hand off to lost-edit-transcript-recovery to reconstruct content from the agent's transcript.
compatibility: Requires git. Works in any git worktree the background agent wrote to; cloud-compatible.
---

# Subagent Edit Verify

A background agent's completion report describes what it *believes* it did — not what is actually on disk. Between the agent writing a file and the parent reading its report, a concurrent checkout, a stash pop from another session, or a worktree collision can silently revert or clobber the change. Trusting the report without checking is how that loss goes unnoticed until session-close, if anyone notices at all.

**Generalizes** the pattern the dev-team pipeline already applies narrowly: before trusting Coder's "done" report, dev-team-manager checks actual repo state (`git status --short`, `git log main..HEAD --oneline`) rather than the Coder's own summary. This skill names that pattern and applies it to *any* background agent reporting a file write — not just dev-team's Coder.

## Trigger

Run this check immediately after any background Agent — a generic subagent spawn, `dev-team-coder`, or any other orchestrated agent — reports completing a file write or edit task. Run it before the parent session does anything downstream with that report (merging, handing off to the next pipeline step, or simply telling the user "done").

Do not defer this to session-close. The whole point is catching the loss immediately after it happens, while the agent's transcript and worktree state are still fresh.

## Verification steps

In the agent's actual worktree (not from the agent's own summary):

1. **File exists as claimed** — `ls` or `test -f` the path(s) the agent said it touched. A reported edit to a file that isn't there is an immediate red flag.
2. **Change actually landed** — `git status --short` and `git diff` (or `git log -1 -p` if committed) in that worktree. Compare the actual diff against what the agent *specifically* reported changing — not "a file changed," but the reported content change itself (the added function, the corrected value, the new section).
3. **No silent clobbering** — check the file isn't a stale/reverted version despite the agent's report. A concurrent checkout or another session's `git checkout`/`stash pop` in a shared worktree can revert content after the agent wrote it but before the parent checks. `git log -1 --format=%H -- <file>` plus a content diff against what was reported catches this even when `git status` looks clean.

## When verification finds a mismatch

Do not silently re-trust a re-run and do not re-spawn a duplicate agent as a first response. Treat the mismatch as a real finding:

- Report it explicitly — which file, what was claimed, what's actually there.
- If the reported content needs to be reconstructed, hand off to **`lost-edit-transcript-recovery`** — it greps the agent's own JSONL transcript for its Edit/Write tool_use blocks to recover the lost content, rather than re-deriving it from scratch or guessing.
- Only fall back to re-spawning the agent if recovery isn't viable and the task must be redone.

## Related skills

- **`subagent-completion-verify`** — confirms the agent's task is actually finished (commit landed, report actually written) before trusting a "completed" status at all. Run that check first if there's any doubt the agent finished; run this skill once you have a completion report and need to confirm its *content* matches disk.
- **`lost-edit-transcript-recovery`** — the recovery procedure to use once this check finds a mismatch.
