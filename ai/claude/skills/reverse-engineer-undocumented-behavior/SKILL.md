---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: reverse-engineer-undocumented-behavior
description: Determine an undocumented third-party or internal system's actual runtime behavior by cloning its source repo(s) and reading the implementation directly, when no doc exists anywhere for the specific behavior in question. Distinct from ordinary code review or debugging — the goal is one ground-truth behavioral fact (not a code change), scoped to the function/module that decides it, written down durably (a wiki page or memory file) so it isn't re-derived next time. Use when asked "how does X actually decide Y", "why does this system behave this way with no doc for it", "reverse-engineer this bot's/service's behavior", "read the source to find out how this works", or when a doc search has already come up empty everywhere docs would normally live (team wiki, the system's own docs repo, README) — not merely hard to find with one search. Complements vault-support and similar retrieval-bot skills, which document known quirks of a specific bot rather than deriving new ground-truth facts from source.
compatibility: Requires read access to clone the relevant source repo(s). No write/PR intent — this skill only reads and documents, it does not change the target system's code.
---

# Reverse-Engineer Undocumented Behavior

Some systems have no documentation for a specific behavior anywhere — not because it's hard to find, but because it was never written down. The only ground truth is the implementation itself. This skill scopes a source-reading pass narrowly enough to answer one question, then makes sure the answer survives past this session.

## When to use this vs. ordinary debugging

Use this skill only after confirming docs genuinely don't exist for the specific behavior in question:

1. Searched the team wiki / knowledge base for the behavior — nothing
2. Searched the system's own docs repo or README — nothing
3. Asked whoever owns the system, if reachable — no answer or "not documented"

If any of those turns up an actual answer, this isn't the right skill — go read the doc instead. This skill is for the gap that's left after documentation genuinely doesn't exist, not a shortcut past a documentation search that just needs another query.

This is also distinct from ordinary code review or debugging: the goal isn't to fix or change anything in the target system. It's to extract a factual, byte-accurate answer to "what does this system actually do" and write it down.

## Step 1 — State the exact question before cloning anything

Write down the specific behavioral question in one sentence — e.g. "which wiki pages does the retrieval bot's ranking function actually consider before returning an answer." A vague goal ("understand how the bot works") leads to reading the whole codebase; a precise question leads to one function.

## Step 2 — Clone only the repo(s) that could contain the answer

Identify the specific service/component responsible for the behavior (from architecture docs, deploy configs, or asking someone who knows the system's shape, even if they don't know the specific answer). Clone only that repo — not every repo in the system's dependency graph.

```bash
git clone <source-repo-url> /tmp/reverse-engineer-<system-name>
```

Use a scratch/temp location — this clone is for reading, not for contributing back.

## Step 3 — Find the specific function or module, not the whole codebase

Search for the behavior's likely entry point rather than reading top-to-bottom:

```bash
grep -rn "<keyword from the question>" /tmp/reverse-engineer-<system-name>/src
```

Look for the function that makes the actual decision (a ranking function, a filter, a config parser) — not every file that merely calls it. Trace inward from an entry point (an API handler, a CLI command) only as far as needed to reach the decision point, then stop. Reading the whole codebase to answer one narrow question is the failure mode this skill exists to avoid.

## Step 4 — Verify the finding is the actual runtime path, not dead code

Before trusting what you found, check:

- Is this function actually called in the path that produces the observed behavior (trace one call site up), or is it unreferenced/deprecated code sitting in the same file?
- Does a config flag or feature flag gate whether this code path runs at all? Check the relevant config for the environment being observed.
- If a version tag or branch is deployed differently than `main`, confirm you're reading the version actually running in production, not a newer or older one.

## Step 5 — Write the finding down as a byte-accurate fact, not an inference

State exactly what the code does, citing the file and function — not what it's "probably trying to do." Follow this repo's own convention from `docs/guides/skill-conventions.md`: describe the *observed* mechanism with a citable source (the actual file/function read), not an invented rule about how the system behaves. If the behavior seems surprising or unintuitive, say so plainly rather than rationalizing it into something that sounds more deliberate than the code shows.

## Step 6 — Store the finding somewhere durable

Pick one, based on what already exists for this system:

- **A wiki page** (via `memex-capture-thread`-style vault conventions, or the team's existing wiki) if other people will hit this same question
- **A project memory file** if this is personal/session-scoped knowledge relevant mainly to future sessions in this repo
- **A comment or note in the skill/doc that hit the gap** (e.g. `vault-support`'s own "known behavior" notes) if the finding explains a specific quirk that skill already has to work around

Include: the exact question answered, the file/function that answers it, the source repo and commit/tag read, and the date. A finding without a source citation is exactly the kind of unverifiable claim this repo's conventions warn against — don't let the durable write-up drop the citation the investigation actually had.

## Step 7 — Clean up the clone

Once the finding is written down, remove the scratch clone (`rm -rf /tmp/reverse-engineer-<system-name>`) unless there's a concrete reason to keep it around for a follow-up question.
