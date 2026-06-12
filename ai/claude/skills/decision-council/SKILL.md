---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: decision-council
description: Run any decision, plan, or tradeoff through 5 AI advisors with distinct thinking styles, a blind peer review round, and a final chairman synthesis. Based on Karpathy's LLM Council methodology. TRIGGERS: "council this", "decision council", "run the council", "war room this", "pressure-test this", "stress-test this", "debate my options", "gut check this", "get a second opinion on this", "talk me out of this". STRONG TRIGGERS when combined with a real decision: "should I X or Y", "which option", "I can't decide", "I'm torn between", "validate this decision". Do NOT trigger on: factual lookups, creation tasks (write me X), or casual questions without a meaningful tradeoff.
---







# Decision Council

Runs your question through 5 parallel advisors, a blind peer review round, and a chairman synthesis. Best for decisions where being wrong is expensive.

**Complement:** `grill-me` interrogates a plan interactively — this stress-tests a decision asynchronously through independent perspectives.

---

## Step 1 — Frame the question

Before spawning advisors, do two things:

**A. Load context.** Scan for files that give advisors grounded, specific context rather than generic advice:

- Read memory files at `~/.claude/projects/*/memory/` — anything relevant to the question (audience, goals, constraints, past decisions)
- Read any files the user referenced or attached in this conversation
- Spend no more than 30 seconds — grab the 2–3 files that matter most

**B. Write the framed question.** Produce a clean, neutral prompt that includes:

1. The core decision or question
2. Key context from the user's message
3. Key context from memory (goals, constraints, relevant history or numbers)
4. What's at stake — why a bad call here is costly

Do not steer the framing. Hold the framed question in your context — include it verbatim in every advisor and reviewer prompt below.

If the question is too vague to frame, ask one clarifying question, then proceed.

---

## Step 2 — Convene the council (5 sub-agents in parallel)

Tell the user: "Running the decision council — spawning 5 advisors in parallel. This takes 2–4 minutes."

Spawn all 5 advisors simultaneously. Each gets their identity, the framed question, and this instruction:

> Respond independently. Do not hedge. Lean fully into your assigned perspective. State your strongest take — the synthesis comes later. 150–300 words, no preamble.

**The five advisors:**

- **The Contrarian** — actively looks for what's wrong, what's missing, what will fail. Assumes a fatal flaw exists and tries to find it. Not a pessimist — the friend who saves you from a bad deal.
- **The First Principles Thinker** — strips assumptions and rebuilds from the ground up. Often surfaces "you're asking the wrong question entirely."
- **The Expansionist** — looks for upside and adjacent opportunity everyone else is missing. Not concerned with risk — that's the Contrarian's job.
- **The Outsider** — zero context about you or your field. Responds purely to what's in front of them. Catches the curse of knowledge: what's obvious to you but confusing to everyone else.
- **The Executor** — only cares about "can this actually be done, and what's the fastest path?" Translates every idea into: what do you do Monday morning?

Sub-agent prompt template:

```
You are [Advisor Name] on a Decision Council.

Your thinking style: [description above]

Question brought to the council:
---
[framed question]
---

Respond from your perspective. Be direct and specific. Do not hedge. Lean fully into your assigned angle — the other advisors cover what you're not covering. 150–300 words, no preamble.
```

---

## Step 3 — Peer review (5 sub-agents in parallel)

Collect all 5 advisor responses. Anonymize as Response A–E (randomize the mapping — no positional bias).

Spawn 5 new sub-agents. Each sees all 5 anonymized responses and answers three questions:

1. Which response is strongest and why? (pick one)
2. Which has the biggest blind spot? What is it missing?
3. What did ALL five miss that the council should consider?

Reviewer prompt template:

```
You are reviewing the outputs of a Decision Council. Five advisors independently answered this question:
---
[framed question]
---

Anonymized responses:

**Response A:** [response]
**Response B:** [response]
**Response C:** [response]
**Response D:** [response]
**Response E:** [response]

Answer these three questions. Be specific. Reference responses by letter. Under 200 words total.

1. Which response is strongest? Why?
2. Which has the biggest blind spot? What is it missing?
3. What did ALL five miss?
```

---

## Step 4 — Chairman synthesis

One final agent receives: the framed question, all 5 de-anonymized advisor responses, and all 5 peer reviews.

The chairman's job: produce a clear verdict. The chairman can dissent from the majority if the dissenting reasoning is stronger — that's the point.

Chairman prompt template:

```
You are the Chairman of a Decision Council. Synthesize the work of 5 advisors and their peer reviews into a final verdict.

Question:
---
[framed question]
---

ADVISOR RESPONSES:
**The Contrarian:** [response]
**The First Principles Thinker:** [response]
**The Expansionist:** [response]
**The Outsider:** [response]
**The Executor:** [response]

PEER REVIEWS:
[all 5 reviews]

Produce the council verdict using this exact structure. Be direct. Do not hedge.

## Where the Council Agrees
[Points multiple advisors converged on independently — high-confidence signals]

## Where the Council Clashes
[Genuine disagreements — present both sides, explain why reasonable advisors differ]

## Blind Spots Caught
[Insights that only emerged through peer review — things individual advisors missed]

## The Recommendation
[A clear, direct recommendation. Not "it depends." A real answer with reasoning.]

## One Thing to Do First
[A single concrete next step — not a list]
```

Present the full verdict in chat as markdown. No files generated unless the user asks.

---

## Step 5 — Save transcript (optional)

Save only if the user requests it or the decision warrants future reference:

```bash
mkdir -p ~/Projects/personal/memex/Outputs/Council/
```

Write to: `~/Projects/personal/memex/Outputs/Council/council-[YYYY-MM-DD]-[topic].md`

---

## Execution notes

- **Spawn all advisors in parallel** — sequential spawning lets earlier responses bleed into later ones
- **Anonymize for peer review** — knowing which advisor said what creates deference bias; reviewers evaluate on merit, not source
- **Don't council trivial questions** — if one right answer exists, just answer it; the council is for genuine uncertainty

---

See [references/upstream.md](references/upstream.md) for the design lineage and what to watch in upstream repos.
