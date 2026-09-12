---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: lost-edit-transcript-recovery
description: Last-resort recovery for a file edit confirmed lost — not in `git stash list`, not in `git reflog` — by grepping the authoring background agent's own JSONL transcript for its Edit/Write tool_use blocks to recover the exact old_string/new_string (or content) it used, so the change can be reconstructed and reapplied instead of treated as unrecoverable. Trigger on "lost edit", "content got overwritten and it's not in stash/reflog", "recover what the agent wrote", "reconstruct from the transcript", "the subagent's changes disappeared", "grep the transcript for the edit", or after a subagent-edit-verify (or equivalent) check confirms a write never landed and normal git recovery has already failed.
compatibility: Requires access to the authoring agent's transcript JSONL file (path varies by environment) and either `jq` or Python for parsing.
---

# Lost Edit Transcript Recovery

Recovers lost file content by reading it back out of the JSONL transcript of the agent that wrote it — used only after normal git-based recovery has already failed.

## Precondition — confirm the loss first

This is a last-resort procedure, not a first check. Before using it, confirm both:

1. `git stash list` — the content is not sitting in an uncommitted stash.
2. `git reflog` (and `git fsck --lost-found` if reflog is inconclusive) — the content was never committed, or the commit isn't reachable any other way.

If either turns up the content, recover from git directly — it's cheaper and doesn't require locating a transcript. Only fall through to this skill once both come up empty.

If a detection check such as **`subagent-edit-verify`** (the skill that checks whether an agent's *reported* writes actually landed on disk) is what surfaced the loss, treat this skill as its recovery step — the detection check tells you a write is missing; this skill is how you get it back.

## The technique

Claude Code agent transcripts are JSONL files — one JSON object per line — containing the full tool-call history for that agent, including every `Edit` and `Write` tool_use block with its exact parameters: `file_path` plus `old_string`/`new_string` for `Edit`, or `file_path` plus `content` for `Write`.

1. **Locate the transcript.** Background agents each write to their own per-task transcript file; the exact path pattern (working directory, task ID, log root) varies by environment, so find it for the current environment rather than assuming a fixed path — don't hardcode a path from a prior session.
2. **Grep/filter for the lost file.** Extract only the `tool_use` entries whose `name` is `Edit` or `Write` and whose `input.file_path` matches the lost file's path.
3. **Read them in call order.** The transcript is append-only in the order calls happened, so the last matching entry (or the full ordered sequence, for a file rebuilt across several edits) reflects the agent's final intended content.

### Extraction one-liners

`jq`, filtering a transcript for one file's Edit/Write blocks:

```bash
jq -c 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use" and (.name=="Edit" or .name=="Write"))
  | select(.input.file_path=="/absolute/path/to/lost_file.ext")
  | {name, file_path: .input.file_path, old_string: .input.old_string,
     new_string: .input.new_string, content: .input.content}' \
  transcript.jsonl
```

Python equivalent, when `jq` isn't available or the output needs more processing:

```python
import json

target = "/absolute/path/to/lost_file.ext"
with open("transcript.jsonl") as f:
    for line in f:
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("type") != "assistant":
            continue
        for block in entry.get("message", {}).get("content", []) or []:
            if block.get("type") != "tool_use":
                continue
            if block.get("name") not in ("Edit", "Write"):
                continue
            inp = block.get("input", {})
            if inp.get("file_path") == target:
                print(json.dumps(inp, indent=2))
```

## Reconstruction

Concatenate/apply the extracted `new_string` (or `content`, for a `Write`) values in call order to rebuild what the agent intended the file to contain.

Before reapplying, check whether any fact embedded in that content has changed since the original call — a referenced line number, a value that was correct at write time but has since shifted, a path that moved. The transcript gives you the agent's *intent*, not a guarantee it's still accurate; update anything stale before reapplying.

## Reapplication

1. Apply the reconstructed content as a fresh `Edit` or `Write` against the current file state.
2. Verify it landed — re-read the file and diff it against what you reconstructed.
3. Commit normally, per `git-ops`.

## Related skills

- **`subagent-edit-verify`** — the detection half: checks whether an agent's reported writes actually landed. Run that check (or an equivalent one) first; this skill's precondition assumes loss is already confirmed, not merely suspected.
- **`session-close`** — its transcript-reconciliation check is what typically surfaces a confirmed loss that should route here.
