---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-29
updated_by: cursor
---

# ATS and keyword-stuffing signals

Separate from AI-authorship detection. Candidates increasingly keyword-load resumes to pass automated HR filters — **expected behavior**, not inherently dishonest. Report **severity** and context.

## Patterns

| Pattern | Severity guide | Notes |
| ------- | -------------- | ----- |
| **Dense skills matrix** | High when >30 tools/frameworks in list form with thin narrative | Three cloud platforms + every CI/CD + every observability stack in one block |
| **Tri-cloud headline** | Medium | Azure \| AWS Certified \| GCP in title for a role needing depth in one |
| **JD-complete coverage** | High when resume hits every posting keyword with no depth anywhere | Compare against opening must-haves when JD is loaded |
| **Checkbox cloud** | Medium | Lists Lambda, EKS, GKE, AKS, CloudFormation, ARM, Deployment Manager without role-specific stories |
| **Compliance keyword spray** | Low–Medium | NIST, ISO 27001, HIPAA, SOC 2, CIS in skills line with no audit/incident context |
| **Textio-style summary** | Low | Generic leadership + "proven track record" + "cross-functional" opener |

## Severity vs decision

| Severity mix | Typical read |
| ------------ | ------------ |
| High ATS + High authenticity mismatch | Verify live — treat resume as unreliable |
| High ATS only | Normal modern job search — probe depth, don't penalize keywords |
| Low across both | Paper looks consistent — still require live screen before client forward |

## JD comparison (when opening loaded)

Count must-have hits vs nice-to-have. Flag:

- **Resume > conversation** on a must-have (prior screener noted gap)
- **Unlikely role slot** — e.g. GCP specialist slot but screener validated Azure-first

Report in the ATS table and cross-reference JD fit table — do not duplicate the same gap in both without adding distinct angle (keyword density vs skill mismatch).
