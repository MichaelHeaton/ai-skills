---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: memex-decide
description: Log a finalized decision into the Memex wiki as a persistent ADR-style document. Use when a decision has been reached through a structured process (decision council, research, discussion) and needs a permanent home — not a ticket. Writes to Wiki/Concepts/{Topic}-Decision.md, updates Wiki/log.md, Wiki/index.md, Wiki/Concepts/README.md, and Wiki/overview.md. Does NOT create a ticket — that's memex-dump's job. Trigger on: "log this decision", "document this decision", "write this up as a decision", "save this to the wiki", "archive this decision", "memex this decision", "create a decision doc", "add this to the wiki", at the end of a decision-council run when the user says to save or archive the output. SKIP when the user wants to capture a raw thought, idea, or unresolved question — use memex-dump for those.
---





# memex-decide

Writes a finalized decision to the Memex wiki as a persistent, searchable document. Decisions are not tasks — they have no completion state and should never live in a ticket that will close and disappear.

**Complement:** `memex-dump` handles unstructured captures → tickets. `decision-council` runs the analysis that produces the decision. This skill archives what was decided.

---

## Step 1 — Extract decision details

Gather from context (don't ask for things already in the conversation):

- **Title** — short, noun-phrase description of what was decided (e.g., "AI Account Architecture Across Work and Personal Domains")
- **Domain** — one of: `personal`, `work-primary`, `client-contract`, `homelab`, `learning`, `mtb`, `iot`
- **Decision** — 1–3 sentence summary of what was decided
- **Context** — why this decision was needed
- **Rationale** — why this option was chosen over alternatives
- **Alternatives rejected** — what was considered and ruled out
- **Consequences** — what changes; what to watch for
- **Source** — how the decision was reached (decision council, research, discussion, etc.)

If any required field is missing and can't be inferred from context, ask once before proceeding.

---

## Step 2 — Derive the filename and path

Filename: `{Topic-In-Title-Case}-Decision.md`

Rules:

- Topic-based, not date-based — optimizes for retrieval by subject, not chronology
- Title case with hyphens: `AI-Account-Architecture-Decision.md`
- No date prefix
- End in `-Decision`

Full path: `~/Projects/personal/memex/Wiki/Concepts/{filename}`

Check if a file with this name already exists. If it does, confirm with the user before overwriting.

---

## Step 3 — Write the decision document

```bash
cat > ~/Projects/personal/memex/Wiki/Concepts/{filename} << 'EOF'
---
tags: [wiki, domain/{domain}, decision]
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
---

# Decision: {Title}

## Decision

**Date**: {YYYY-MM-DD}
**Status**: Decided

{1–3 sentence summary}

## Context

{Why this decision was needed}

## Rationale

{Why this option was chosen}

## Alternatives Rejected

{What was considered and ruled out, and why}

## Consequences

{What changes as a result; what to watch for going forward}

## Source

{How the decision was reached — decision council, research, team discussion, etc.}
EOF
```

---

## Step 4 — Update wiki navigation files

Update all four files. Each update is a targeted append or insert — do not rewrite the whole file.

**Wiki/log.md** — prepend a new entry at the top of the log (after the `# Wiki log` header):

```
## [{YYYY-MM-DD}] decision | {short description}

- New [[Wiki/Concepts/{filename-without-extension}|{Title}]]; {one-line summary of the decision}. Source: {source}.
```

**Wiki/index.md** — add a `## Decisions` section if one doesn't exist, then append the link:

```
- [[Wiki/Concepts/{filename-without-extension}|{Title}]] — {one-line description}
```

**Wiki/Concepts/README.md** — append a link at the end of the file:

```
- [[Wiki/Concepts/{filename-without-extension}|{Title}]] — {one-line description}
```

**Wiki/overview.md** — append a link under a `## Decisions` section (create the section if absent).

---

## Step 5 — Handle related open ticket (optional)

If there is an open Memex GitHub Issue related to this decision (user mentions a ticket number, or one was created during this session):

1. Add a comment to the issue linking to the decision doc
2. Apply the `decision-logged` label (create it if it doesn't exist)
3. Close the issue

```bash
export GH_TOKEN=$(gh auth token --user "${GITHUB_PERSONAL_USER:-YOUR_USER}")

# Add comment
gh issue comment {NUMBER} \
  --repo ${routing.personal_kb_github} \
  --body "Decision logged: [Wiki/Concepts/{filename}](../blob/main/Wiki/Concepts/{filename})"

# Add label (seed first)
gh label create "decision-logged" --repo ${routing.personal_kb_github} --color "0075ca" --description "Decision captured in wiki" 2>/dev/null || true

# Close with label
gh issue edit {NUMBER} --repo ${routing.personal_kb_github} --add-label "decision-logged"
gh issue close {NUMBER} --repo ${routing.personal_kb_github}
```

If no related ticket exists, skip this step silently.

---

## Step 6 — Confirm

Report what was created and updated:

```
✓ Wiki/Concepts/{filename}
✓ Wiki/log.md — entry added
✓ Wiki/index.md — link added
✓ Wiki/Concepts/README.md — link added
✓ Wiki/overview.md — link added
✓ Issue #{N} closed with decision-logged label  (or: no related ticket)
```

Remind the user to commit: `git commit && git push` in the Memex repo to persist the change.

---

## Notes

- **No ticket is created by this skill** — the decision is already made. Tickets are for unresolved work.
- **No MEMORY.md entry** — future sessions find decisions via Memex wiki search.
- **`Raw/_task-index.jsonl` is not updated by this skill** — decision docs don't create new issues. If a related ticket existed, its index entry was already written when that ticket was created. No additional index entry is needed.
- **Transcript preservation** — if the decision came from a decision council and the user wants to save the full council transcript, write it to `~/Projects/personal/memex/Outputs/Council/council-{YYYY-MM-DD}-{topic}.md` before closing the session. This is separate from the decision doc.
