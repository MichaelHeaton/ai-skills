---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: cursor
---


# Resume authenticity signals

Informational heuristics — not proof of ChatGPT use and not grounds for auto-rejection. Assign **confidence** (High / Medium / Low) and cite specific resume evidence.

## Structural tells

| Pattern | What to look for |
| ------- | ---------------- |
| **Metric rhythm** | Nearly every bullet ends with a round percentage (25%, 40%, 50%). Real practitioners mix quantified and unquantified outcomes. |
| **Verb uniformity** | Every bullet opens with Led / Architected / Designed / Implemented / Engineered — polished but interchangeable; ownership unclear. |
| **Parallel perfection** | Same sentence shape across all roles and years; no rough edges, typos, or uneven detail. |
| **Missing specifics** | No named systems, teams, incidents, tradeoffs, or failures across long tenures. |

## Content tells

| Pattern | What to look for |
| ------- | ---------------- |
| **Scope inflation** | "Architected enterprise-scale", "Zero Trust / FedRAMP / NIST" claims disproportionate to title and tenure. |
| **GenAI narrative clustering** | Agentic AI, RAG, MCP, LLM orchestration stacked without clear personal ownership boundaries. |
| **Resume vs screener mismatch** | Recruiter validated weaker skill than resume claims (e.g. limited Python vs Django/Flask bullets) — **High confidence** when documented. |
| **Self-rating without depth** | "7.5/10 Terraform" in conversation but resume only lists tools, not module/drift stories. |

## What is NOT a signal

- Non-native English or formal phrasing alone
- Professional resume writer polish
- Career pivot with genuinely broad but shallow exposure
- Certifications that match listed skills

## How to report

Group findings in the authenticity table. When confidence is Medium+, tie each row to a **live probe** in Phase B (contradiction or depth ladder).

When multiple High signals stack **and** a prior screener flagged gaps, set verdict preview to **Needs live screen to decide** with lean Hold/No — never Hard No from paper alone unless user requests paper-only disposition.
