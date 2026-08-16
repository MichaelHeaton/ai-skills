---
version: 1.3.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: decision-council
description: Run any decision, plan, or tradeoff through 7 AI advisors with distinct thinking styles, a blind peer review round, and a final chairman synthesis. Based on Karpathy's LLM Council methodology. TRIGGERS: "council this", "decision council", "run the council", "war room this", "pressure-test this", "stress-test this", "debate my options", "gut check this", "get a second opinion on this", "talk me out of this". STRONG TRIGGERS when combined with a real decision: "should I X or Y", "which option", "I can't decide", "I'm torn between", "validate this decision". Do NOT trigger on: factual lookups, creation tasks (write me X), or casual questions without a meaningful tradeoff.
---

# Decision Council

Runs your question through 7 parallel advisors, a blind peer review round, and a chairman synthesis. Best for decisions where being wrong is expensive.

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
5. **For infra/ops questions** (deployment topology, network reachability, CI/tooling choices, anything where "does the environment actually support this" changes the answer): explicitly ask for environmental constraints — LAN/network reachability, available CI runners, existing tooling gaps — as part of gathering context, not left for advisors to guess or peer review to catch after the fact. Advisors under-specifying these constraints in their framing, and peer review catching what framing should have, is a recurring pattern on infra councils specifically.

Do not steer the framing. Hold the framed question in your context — include it verbatim in every advisor and reviewer prompt below.

If the question is too vague to frame, ask one clarifying question, then proceed.

---

## Step 1.5 — Scale the council to the decision (optional)

**Don't bundle unrelated questions into one pass to save cost.** If two or more questions are genuinely separate decisions (different stakes, different stakeholders, only coincidentally pending at the same time — e.g. a ticket-sequencing call and a repo-architecture call), run separate council passes and scale each one with the levers below. Bundling them into a single framed question breaks assumptions downstream: advisors have to split 150–300 words across topics instead of engaging either one fully, and the landslide-consensus shortcut below cannot tell "converged on everything" from "converged on one thing, split on the other" without per-question tracking it isn't built for. If the questions are facets of one real decision (same stakeholders, same stakes, an answer to one changes the other), keep them as one framed question — that's not bundling, that's correct framing. When cost is the actual concern, use the levers below instead:

The full pipeline (7 advisors + 5 peer reviewers + chairman = 13 agent invocations) is the default and the right call for a first-pass, high-stakes decision. It is not mandatory for every invocation — before spawning anything, decide directly (no separate routing agent needed; this is a judgment call for the Architect step to make, the same way `dev-team`'s Manager is a conditional gate rather than a role that always runs) whether a lighter pass fits better:

- **Full pipeline** — first-pass decisions, high-stakes calls, or anything genuinely uncertain across multiple dimensions.
- **Lighter pass** — a follow-up round on a decision already framed by an earlier council run, or a medium-stakes call where the tradeoff space is narrower. Two forms, usable independently or together:
  - **Fewer advisors** — spawn only the 2-3 personas whose perspective actually bears on this question (e.g. Executor + Investor for a narrow feasibility/cost follow-up) instead of all 7.
  - **Skip peer review** — run the advisors, synthesize directly without the 5-reviewer round, when the advisor responses themselves are enough to decide.

Existing behavior — all 7 advisors, full peer review, chairman synthesis — still applies by default whenever this step is skipped or a lighter pass isn't clearly warranted. Don't downgrade a decision that's actually high-stakes just to save tokens.

---

## Step 2 — Convene the council (7, or a routed subset, in parallel)

Tell the user: "Running the decision council — spawning 7 advisors in parallel. This takes 2–4 minutes."

Spawn all 7 advisors simultaneously. Each gets their identity, the framed question, and this instruction:

> Respond independently. Do not hedge. Lean fully into your assigned perspective. State your strongest take — the synthesis comes later. 150–300 words, no preamble.

**The seven advisors:**

- **The Contrarian** — actively looks for what's wrong, what's missing, what will fail. Assumes a fatal flaw exists and tries to find it. Not a pessimist — the friend who saves you from a bad deal.
- **The First Principles Thinker** — strips assumptions and rebuilds from the ground up. Often surfaces "you're asking the wrong question entirely."
- **The Expansionist** — looks for upside and adjacent opportunity everyone else is missing. Not concerned with risk — that's the Contrarian's job.
- **The Outsider** — zero context about you or your field. Responds purely to what's in front of them. Catches the curse of knowledge: what's obvious to you but confusing to everyone else.
- **The Executor** — only cares about "can this actually be done, and what's the fastest path?" Translates every idea into: what do you do Monday morning?
- **The Investor** — asks whether this makes money or is worth the resources it costs. Strategic and financial: ROI, opportunity cost, what this displaces. Not concerned with feasibility — that's the Executor's job.
- **The Customer** — asks whether anyone actually wants this. Represents the end user's indifference, not the builder's enthusiasm. A clever solution to a problem nobody has is still a failure from this seat.

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

## Landslide-consensus shortcut (after Step 2, before Step 3)

After collecting the advisor responses, do a quick scan: if 6 or more of the 7 converge independently on the same conclusion, skip Step 3 (peer review) and Step 4 (chairman synthesis) — synthesize the verdict directly from the advisor responses instead. Peer review and a chairman round add little when the council already agrees this strongly; running them anyway is process for its own sake.

**When the shortcut is taken, say so in the output** — a line noting "6/7 advisors converged independently; peer review and chairman synthesis skipped" — rather than silently presenting a verdict that looks like it went through the full pipeline when it didn't. Anything short of a landslide (5 or fewer converging, or real disagreement) proceeds through the full Step 3 + Step 4 as normal.

**Scope: this shortcut is defined for one question per pass.** It assumes "converge on the same conclusion" is unambiguous — true for a single question, not guaranteed for a bundled one (see Step 1.5: bundling is discouraged for this reason). If a pass ever does cover more than one question anyway, evaluate convergence separately per question and only take the shortcut if *every* question in the pass independently clears 6-of-7 — one question landsliding does not license skipping peer review for another question riding along in the same responses. If any question falls short, run the full Step 3 + Step 4 for the whole pass; there is no partial shortcut that reviews one question and not the other.

---

## Step 3 — Peer review (5 sub-agents in parallel)

Collect all 7 advisor responses. Anonymize as Response A–G (randomize the mapping — no positional bias).

Spawn 5 new sub-agents. Each sees all 7 anonymized responses and answers three questions:

1. Which response is strongest and why? (pick one)
2. Which has the biggest blind spot? What is it missing?
3. What did ALL seven miss that the council should consider?

Reviewer prompt template:

```
You are reviewing the outputs of a Decision Council. Seven advisors independently answered this question:
---
[framed question]
---

Anonymized responses:

**Response A:** [response]
**Response B:** [response]
**Response C:** [response]
**Response D:** [response]
**Response E:** [response]
**Response F:** [response]
**Response G:** [response]

Answer these three questions. Be specific. Reference responses by letter. Under 200 words total.

1. Which response is strongest? Why?
2. Which has the biggest blind spot? What is it missing?
3. What did ALL seven miss?
```

---

## Step 4 — Chairman synthesis

One final agent receives: the framed question, all 7 de-anonymized advisor responses, and all 5 peer reviews.

The chairman's job: produce a clear verdict. The chairman can dissent from the majority if the dissenting reasoning is stronger — that's the point.

Chairman prompt template:

```
You are the Chairman of a Decision Council. Synthesize the work of 7 advisors and their peer reviews into a final verdict.

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
**The Investor:** [response]
**The Customer:** [response]

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
