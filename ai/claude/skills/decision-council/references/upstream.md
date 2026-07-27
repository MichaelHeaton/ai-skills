---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-07-27
updated_by: claude
---

# Upstream Reference — Decision Council

## Design lineage

**Primary source:** [`karpathy/llm-council`](https://github.com/karpathy/llm-council)

Karpathy's original uses *multiple real AI models* (GPT, Gemini, Claude, Grok) queried in parallel via OpenRouter. Peer review is a ranking (1-N with evaluation per response). The chairman synthesizes rankings + responses into a free-form final answer with no structured output sections. Designed as a local web app for comparing models while reading books — not a decision-making skill.

**Intermediate adapter:** [`aiwithremy/ai-skills-llm-council`](https://github.com/aiwithremy/ai-skills-llm-council)

Adapted the methodology for Claude Code as a single-model skill. Key changes from Karpathy:

- Replaced model diversity with 5 thinking-style personas (Contrarian, Expansionist, etc.)
- Replaced the ranking format with the 3-question peer review
- Added structured chairman output sections (agreements, clashes, blind spots, recommendation, one thing)
- Added use-case guidance (when to use / skip)
- Added workspace context scanning

**Our version (decision-council):** adapted from aiwithremy with our conventions, memory layout, and output style. The 3-question peer review and structured chairman output are aiwithremy's own additions — both are improvements over Karpathy's original for decision-making.

## Known tradeoff

Karpathy's strength is genuine model diversity (different architectures, training data, tendencies). Our version substitutes persona diversity within a single model — Claude playing "Contrarian" is still Claude. This is a fundamental constraint of single-model skills, not a bug to fix, but worth understanding when the council output feels too coherent.

## What to watch in upstream

- **`aiwithremy`:** advisor descriptions, peer review format, chairman structure, new trigger patterns
- **`karpathy`:** core methodology changes — if he changes the ranking/review design, evaluate whether to adopt it

GitHub issue [#103](https://github.com/YOUR_USER/ai-skills/issues/103) tracks this upstream relationship.

## 2026-07-27: added Investor and Customer personas

A third source surfaced this time: an AI-tip video proposing a 4-persona "board of advisors" (Elite Operator, Investor, Customer, Skeptic). Ran it through this skill's own decision-council process rather than adopting it wholesale. Diff result: Elite Operator and Skeptic duplicated the existing Executor and Contrarian; Investor and Customer were genuine gaps (no existing persona asked "does this make money" or "does anyone want this"). Added those two as a 6th/7th persona rather than swapping out any of the original 5.

Deliberately **not** bundled with this change: a "council leader" routing/gating agent to conditionally select a subset of personas per question (the always-run-all-N behavior is unchanged). That's tracked separately in issue [#171](https://github.com/MichaelHeaton/ai-skills/issues/171), so a future regression is attributable to one change at a time.
