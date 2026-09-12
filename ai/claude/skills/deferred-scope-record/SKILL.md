---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: deferred-scope-record
description: Capture a mid-session deferral as a structured record — the deferred item, the rationale for deferring it, the specific unblocking condition, and a durable ticket or vault note — so a future session doesn't re-litigate a decision that was already made. Distinct from memex-dump, which is unstructured raw-idea capture with no deferral schema. Trigger on phrasing like "won't invest in X", "defer X until Y", "skip X for now", "X is out of scope this session", or clear equivalents that state a deferral decision has already happened.
compatibility: Ticket path requires the issue-create skill's own tooling (gh CLI or MCP fallback). Vault note path requires a local Memex vault clone.
---

# Deferred Scope Record

Capture a mid-session deferral as a structured record, not a stray note, so the next session doesn't re-litigate a decision that was already made.

## Distinct from memex-dump

`memex-dump` captures raw, unstructured ideas fast — no schema, triage later. This skill only fires for an active deferral decision (something was considered and explicitly set aside), and it always produces the same four-part record. Use `memex-dump` for "here's a thought"; use this skill for "we decided not to do X right now, here's why, and here's what would change that."

## Trigger phrases

- "won't invest in X"
- "defer X until Y"
- "skip X for now"
- "X is out of scope this session"
- clear equivalents that state a deferral has already happened, not just a passing mention

Don't fire on a plain scope restatement (e.g. "that's not what this ticket asks for") unless it reads as a decision worth remembering later — a one-off scope clarification isn't a deferral record.

## Steps

### 1. Capture the four fields

Ask only for what's missing; infer as much as possible from the conversation already in front of you.

1. **Deferred item** — stated concretely. "Adding refresh-token rotation to the login flow," not "the auth stuff."
2. **Constraint / rationale** — why now isn't the right time: capacity, a dependency not ready yet, out of the current ticket's scope, risk too high, etc.
3. **Unblock condition** — the specific, checkable condition that would make this worth doing. "Once the rate-limiter ships," not "later."
4. **Record location** — ticket or vault note (see routing below).

**Push back once if the unblock condition is vague** ("just whenever," "someday") — an unblock condition that isn't checkable defeats the point of the record. If the user genuinely doesn't have one, record "Unblock condition: none identified — revisit manually" rather than inventing one.

### 2. Choose ticket vs. vault note

- **Ticket** — route through `issue-create`; never call `gh issue create` / `jira_create_issue` directly (per this repo's standing convention). Use this when the deferred item is a unit of future work that should surface in backlog triage — a feature, fix, or follow-up with a "someday gets picked up" shape.
- **Vault note** — use this when the deferral is more like a standing decision or context record: an architectural stance, a policy, a "we're not doing this class of thing" call that isn't itself schedulable work, but is context a future session needs before reopening the topic.

If genuinely ambiguous, default to a **ticket** — it surfaces in triage and can be closed as won't-do later, whereas a vault note that should have been a ticket tends to get forgotten.

### 3. File the record

**Ticket path** — invoke `issue-create` with:

- **Title**: imperative statement of the deferred item
- **Body**: the four fields, structured plainly —

  ```markdown
  **Deferred item:** <item>
  **Rationale:** <constraint/why not now>
  **Unblock condition:** <specific condition>

  *Captured via deferred-scope-record.*
  ```

- **Priority**: `low` unless the user says otherwise — deferred work is rarely urgent by definition.

**Vault note path** — write to the same Memex vault `issue-create` and `memex-dump` use. Append to an existing relevant note if one clearly matches the topic; otherwise create a new note under a `Deferred/` path, using the same four-field structure as the ticket body above. Do not invoke `memex-decide` for this — that skill is for finalized ADR-style decisions with its own template; a deferral is not yet a settled architectural decision.

### 4. Confirm

One line: what was deferred, where it was recorded (ticket link or vault note path), and the unblock condition — so the user can immediately verify the record captured what they meant.
