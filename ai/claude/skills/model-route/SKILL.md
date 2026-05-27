---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: model-route
description: Route tasks and sub-agents to the cheapest model that can reliably complete the work. Use when spawning Agent tool calls, when picking a model for a focused task, or when reviewing whether the current session is over-spending on heavy reasoning. Trigger on: "which model should I use", "route this to haiku", "spin up sub-agents", "model tier", "too expensive", or any time multiple Agent calls are about to be created.
compatibility: Any context. Applies to Agent tool calls and model selection guidance.
---




# Model Routing

Use the cheapest model that can reliably complete the task. Escalation is a last resort, not a default.

**Cost anchors (approximate, relative):** Haiku ≈ 1x · Sonnet ≈ 5x · Opus ≈ 25x

One unnecessary Opus call ≈ 25 Haiku calls. Route deliberately.

---

## Decision table

| Task type | Model |
|---|---|
| File search, locate a symbol, grep | `haiku` |
| Extract, format, summarize, transform data | `haiku` |
| Summarize a Terraform plan or Ansible run | `haiku` |
| Classify an error type (auth / network / config / state) | `haiku` |
| Extract failing resource or task name from output | `haiku` |
| Reformat / deduplicate log output | `haiku` |
| Bounded lookup: "what does X return?" | `haiku` |
| Template filling, boilerplate generation | `haiku` |
| Bug investigation, error analysis | `sonnet` |
| Implementation — feature, fix, refactor | `sonnet` |
| Terraform / Ansible / k8s triage, known failure domain | `sonnet` |
| Code review, test writing, CI debugging | `sonnet` |
| Multi-file analysis, moderate architecture | `sonnet` |
| Ambiguous multi-system incident, Sonnet exhausted | `opus` — only if Sonnet genuinely couldn't converge |
| Hard cross-cutting reasoning, novel tradeoffs | `opus` — only if Sonnet genuinely couldn't converge |
| Complex security analysis, algorithm design | `opus` — only if warranted |

---

## How to apply in Agent tool calls

Specify `model` explicitly when the task tier is clear:

```python
# Light lookup → Haiku
Agent(model="haiku", prompt="Find all files importing X in src/")

# Standard engineering → Sonnet (default, can omit)
Agent(model="sonnet", prompt="Investigate why test Y is flaking")

# Hard reasoning, only when justified → Opus
Agent(model="opus", prompt="Design migration strategy for...")
```

When spinning up parallel sub-agents, route each independently. A search agent and a code-review agent should not both default to Sonnet if one is clearly Haiku-tier.

---

## Escalation rule

Before using Opus, verify:
1. Did Sonnet produce a wrong or incomplete answer on at least one attempt?
2. Is the task genuinely hard — novel reasoning, unstructured tradeoffs, no clear right answer?
3. Or is the prompt underspecified? → Fix the prompt first, not the model.

If the answer to 1 and 2 is yes → use Opus.
If the answer to 3 is yes → rewrite the prompt and retry with Sonnet.

---

## When to invoke this skill

- Before creating multiple `Agent` tool calls in one turn
- When a task feels "expensive" but you haven't questioned why
- When you're about to use Opus by default rather than by deliberate choice
- When simple extraction tasks are being handed to Sonnet-tier reasoning
