---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: design-assumption-audit
description: Before drafting an architecture doc, design proposal, or topology recommendation naming specific tools/stores/mechanisms (a credential store, cloud provider, compute platform, or already-deployed service), probe the environment's documented conventions instead of defaulting to a generic "best practice" choice. Checks AGENTS.md, ~/.config/ai-skills/local.json (or the repo's equivalent config), and known-inventory references for what's already standardized/deployed per category, and flags conflicts before the first paragraph is written, not after a human catches it mid-draft. Use before writing a design doc, architecture proposal, or topology recommendation, or when asked "what does this environment use for X" or "sanity-check this against our setup". Motivated by a session drafting AWS Secrets Manager for a homelab design before the operator corrected it to Vault + Apple Password — a rewrite neither impl-preflight nor grill-me caught, since both fire later.
compatibility: Requires read access to AGENTS.md and, where present, ~/.config/ai-skills/local.json or the repo's equivalent private config.
---

# Design Assumption Audit

A design doc that quietly assumes an infrastructure choice — a credential store, a cloud provider, a compute platform — without checking what this environment actually runs risks a full rewrite once a human catches the mismatch. This skill fires **before the first paragraph is written**, at the design-drafting stage itself, which is earlier than either related skill covers:

- **`impl-preflight`** checks implementation readiness on a ticket already being coded (deployed dependencies, code patterns, resource decisions) — it fires once someone is about to write code, not while a design is still being drafted.
- **`grill-me`** interviews the user about a plan or design already on the table, resolving decision-tree branches through dialogue — it fires on a design that already exists, not before the first draft.

Neither catches an assumption baked silently into a design doc's first draft. This skill does.

## 1. Trigger

About to write an architecture doc, design proposal, or topology recommendation that will name a specific tool, store, or mechanism — a credential store, a cloud provider, a compute platform, or a service assumed to already be deployed.

## 2. Identify the categories the design touches

Before drafting, list each category the design will make a concrete choice about, e.g.:

- Credential/secrets storage
- Compute platform (cloud provider, on-prem, homelab host)
- Network topology (VPN, reverse proxy, exposed ports)
- Existing services the design assumes are already running

## 3. Probe the actual environment for each category

For each category, check — in this order — what's already documented or deployed, rather than reasoning from generic best practice:

1. **`AGENTS.md`** (repo root and any component-level files) for stated conventions
2. **`~/.config/ai-skills/local.json`** (or the target repo's equivalent private config) for environment-specific facts not meant for the public repo
3. **Known-inventory references** — runbooks, prior design docs, wiki pages, or comments that describe what's already standardized or deployed

Don't guess at what these sources say — read them. If a category has no documented answer, say so explicitly rather than filling the gap with a plausible-sounding default.

## 4. Flag conflicts before drafting, not after

If the design's working assumption conflicts with what's actually documented or deployed — recommending a credential store other than the one already standardized, assuming a cloud provider when the target is a homelab host, assuming a service isn't already running when it is — stop and state the conflict plainly before writing the doc:

```
Design touches: credential storage
Documented convention (AGENTS.md / local.json): HashiCorp Vault (OpenBao) + Apple Password
Assumption I was about to draft: AWS Secrets Manager
→ Conflict — confirming before I draft, not after.
```

Ask or state this as a blocking checkpoint. Do not silently draft around the conflict and let a human catch it later — that's the exact failure this skill exists to prevent.

## 5. If no conflict is found

State briefly which categories were checked and confirmed consistent, then proceed with drafting. A clean audit is worth one line, not silence — silence is ambiguous between "checked and clean" and "not checked."
