---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: epic-audit
description: Repo-wide cross-epic hygiene sweep — lists every open epic, parses each body's child-issue rows into a {child_ticket: [epic_numbers]} table, flags duplicate ownership (a ticket tracked in two epic bodies) and misplaced-by-session-adjacency grouping (tickets grouped into an epic because they came up in the same conversation, not because the epic's goal needs them), then proposes or applies fixes per the one-ticket-one-epic convention. Use for "audit the epics", "sweep for duplicate tickets", "check for tickets in two epics", "clean up epic ownership", "find misplaced tickets across epics", or a periodic/on-request repo-wide hygiene pass. Distinct from `epic-workflow` (shaping/refreshing a *single* epic's own content) — epic-audit never shapes an epic's content; it only fixes cross-epic ownership across *all* open epics at once. Use epic-workflow to shape one epic; use epic-audit periodically to keep the set clean against each other.
compatibility: Requires gh CLI with repo access. Cloud-compatible — no local-machine-only paths or tooling.
---

# Epic Audit

A single-epic workflow (`epic-workflow`, if present in this environment) can shape and refresh one epic in isolation, but nothing looks *across* epics for tickets that drifted into the wrong one. That drift happens two ways: the same child ticket gets added as a row to two different epics (duplicate ownership), or a batch of tickets lands in an epic because they were raised in the same conversation as the epic, not because they serve the epic's actual goal (session-adjacency grouping). This skill finds both, across every open epic in one pass, and fixes them under user confirmation.

**Scope boundary:** this skill does not know how to write, restructure, or refresh a single epic's own body content — that is `epic-workflow`'s job (a project-scoped skill; if this repo doesn't have it, treat "the one-ticket-one-epic convention documented in epic-workflow" as a named convention to honor, not a mechanism to imitate). epic-audit only removes/reassigns rows and leaves audit comments. Never use it to draft a new epic or fill in an empty one.

## When to run this

- Periodically, as a standing hygiene pass — the sweep is cheap and idempotent on a repo with few epics.
- On request ("audit the epics", "check for duplicate tickets across epics").
- Right after a session that created or edited several epics in quick succession — that's exactly the condition that produces session-adjacency grouping (see Step 4), and catching it immediately avoids the drift compounding across future sessions.

Do not run this mid-way through actively shaping a single epic with `epic-workflow` — finish that pass first so Step 4's "current epic goal" comparison is judged against the epic's settled scope, not a half-edited one.

## Step 1 — List all open epics

```
gh issue list --repo <owner>/<repo> --label epic --state open --json number,title,body
```

Capture `number`, `title`, and `body` for every result. Paginate (`--limit`) if the repo has enough open epics that the default page size truncates the list — a partial epic list produces false "no duplicate" results for epics you never saw. If fewer than two open epics exist, stop and report "nothing to cross-reference" — this skill has no work to do against a single epic.

## Step 2 — Parse child-issue rows per epic

For each epic body, extract every child-issue reference: checklist rows (`- [ ] #123`), table rows containing an issue number, or bare `#123` / full issue-URL references (including cross-repo `owner/repo#123` form — normalize these to a consistent key so a bare `#123` and its fully-qualified form aren't counted as different tickets). Build one table:

| child_ticket | epic_numbers_it_appears_in |
| --- | --- |
| #123 | [#10] |
| #124 | [#10, #14] |

Note the epic title and stated goal alongside each epic number — you'll need it for Step 4's judgment call. If an epic body has no parseable child rows, record it as empty and move on; don't guess at implicit membership. If a referenced child ticket is closed or no longer exists, note it separately (closed/missing) rather than folding it into the duplicate or misplacement tables — a closed ticket sitting in two epic bodies is stale bookkeeping, not the same problem as an open ticket actively double-tracked.

## Step 3 — Flag duplicate ownership

Any `child_ticket` whose `epic_numbers_it_appears_in` list has more than one entry is a duplicate-ownership violation of the one-ticket-one-epic convention. List every such ticket with both epic numbers and titles. This flag is mechanical — no judgment call needed, no confirmation required to *report* it (confirmation is still required before *editing* anything, per Step 5).

**Deciding which epic keeps the ticket** is still a judgment call, even though *detecting* the duplicate is mechanical: prefer the epic whose stated goal the child ticket's own subject matter actually matches; if both match equally, prefer the epic where the child ticket was added first (check comment/edit history) as the more likely intentional placement. Present your reasoning and recommended keeper alongside both options — do not pick silently.

## Step 4 — Flag misplaced-by-session-adjacency grouping (judgment call — confirm before editing)

For each child ticket, compare its own subject matter against the epic's stated title/goal. Treat a ticket as a candidate misplacement when:

- Its subject doesn't match the epic's stated scope, **and**
- It shares a creation-date or session-context marker with other tickets in the same epic that also don't match (e.g. several "New skill idea: X" tickets filed in the same sitting as the epic, covering unrelated tools) — a cluster that reads as "came up in this conversation" rather than "belongs to this goal".

A single off-topic ticket with no such cluster pattern is weaker evidence than several off-topic tickets sharing a session marker — weigh accordingly, and say so in what you present.

**This is a judgment call, not a mechanical rule.** Present every candidate to the user before touching anything:

- child ticket number + title
- the epic it currently sits in, and why it looks misplaced
- the proposed destination (a different open epic if one fits, or "no epic — remove only")

**Never silently rewrite an epic body based on this heuristic.** Wait for explicit per-ticket or per-batch confirmation. A ticket the user confirms as correctly placed despite the heuristic should be recorded as reviewed-and-kept, not re-flagged on a future sweep without new evidence.

## Step 5 — Apply confirmed fixes

For each confirmed duplicate or misplacement:

1. **Remove the row from the wrong epic body** via `issue-update` *(global: ai-skills)* — edit the epic's body through that skill's issue-edit path, not a raw `gh issue edit` call, so the edit goes through its existing verification/format handling.
2. **Leave a short audit comment** on the wrong epic explaining the reassignment or removal, referencing both epic numbers (source and destination, or "removed, no destination" if there isn't one). Use `issue-update`'s comment command, and verify the comment landed — see `ticket-write-verify` *(global: ai-skills)* if a re-fetch looks mangled.
3. If reassigning to a destination epic, add the row there too, with its own short comment cross-referencing the source epic.

Process fixes one ticket at a time (remove/comment → verify → add-to-destination if any) rather than batching all removals first — a partial failure on one ticket shouldn't leave a row deleted from the source epic with nothing added anywhere else.

## Edge cases

- **Epic references a closed or nonexistent child ticket.** Report it as stale bookkeeping (Step 2), not a duplicate or misplacement — cleaning up dead references is a content edit within one epic, which is `epic-workflow` territory, not this skill's.
- **Two epics both look like a reasonable home and neither is clearly wrong.** Don't force a keeper pick in Step 3 — present both options with your reasoning and let the user decide; recording "user chose to keep in both, epics restructured to share scope" as an explicit outcome is fine if that's what they choose, but it's their call to relax the convention, not this skill's to assume.
- **An epic itself looks mis-scoped** (e.g. its title no longer matches most of its child tickets). That's a single-epic content problem — flag it in the report as a suggestion, but leave the actual re-scoping to `epic-workflow`; don't let this sweep expand into editing the epic's title or description.
- **Cross-repo epics.** If epics for the same program live in more than one repo, run this skill per-repo unless explicitly asked to cross reference across repos — cross-repo issue numbers collide (`#123` means different things in different repos), and silently merging them into one table risks false duplicate matches.

## Report

```
Cross-epic sweep — 6 open epics, 42 child tickets

Duplicate ownership:
✗ #123 tracked in both #10 (Homelab hardening) and #14 (Network segmentation) — user confirmed: keep in #14, removed from #10

Misplaced by session adjacency:
⚠ #201, #202, #203 ("New skill idea: ...") filed same session as #14, unrelated to network segmentation goal — proposed: no epic (standalone). User confirmed for #201, #202; declined for #203 (kept in #14, has a stated reason).

No action needed: 38 tickets, single-epic, on-topic.
```

Never report a ticket as fixed unless its removal/addition and audit comment are both confirmed landed. Tickets the user declined to move stay exactly where they were, recorded as reviewed rather than silently dropped from future sweeps.
