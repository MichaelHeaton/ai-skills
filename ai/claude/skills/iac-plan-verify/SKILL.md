---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
name: iac-plan-verify
description: Parses and tallies `terraform plan -json` / `terraform apply -json` streamed JSONL output (one JSON object per line, e.g. `type: "planned_change"`, `type: "change_summary"`) so you stop hand-counting resource_type occurrences and eyeballing the "Plan: N to add" line. Cross-checks the script's own tally against Terraform's official change_summary, and optionally diffs the plan against an expected-shape file (expected resource counts, resources that must appear, resources that must not appear). Trigger on "verify this terraform plan", "check this plan against expected resources", "tally this apply output", "does this plan match what I expect", "count the resources in this plan", or when a `terraform plan -json` / `apply -json` log is pasted or redirected to a file for review. Not for the single-file `terraform show -json` plan format — that has a different schema. Complements iac-triage (evidence ordering for debugging failures) and iac-reviewer (risk review before apply) — this skill is about mechanical count verification, not risk judgment.
compatibility: Requires Python 3 (stdlib only, no pip install).
---

# IaC Plan Verify

Hand-tallying `terraform plan -json` output is slow and error-prone: counting `resource_type` occurrences by eye, comparing against the printed "Plan: N to add" summary, and checking whether specific resources appear or are absent. `scripts/parse-tf-plan.py` does this mechanically.

**Input**: the streamed JSONL output of `terraform plan -json` or `terraform apply -json` — one JSON object per line, each with a `type` field (`planned_change`, `apply_start`/`apply_complete`, `change_summary`, etc). This is **not** the single-file `terraform show -json` plan format, which has a different schema and isn't handled here.

This skill only parses already-captured JSON text the user pastes, redirects to a file, or streams via a pipe. It never runs `terraform apply` or touches live infrastructure.

---

## Standalone mode — tally summary only

Run without an expected-shape file to get a tally and a cross-check against Terraform's own `change_summary` line:

```bash
terraform plan -json | python3 ai/claude/skills/iac-plan-verify/scripts/parse-tf-plan.py

# or against a saved file
python3 ai/claude/skills/iac-plan-verify/scripts/parse-tf-plan.py plan.jsonl
```

Output includes:

- **Resource type tally** — count of planned changes per `resource_type`
- **Action tally** — count of `create` / `update` / `delete` / `replace` actions
- **Totals vs `change_summary`** — the script's own add/change/remove tally compared against the official summary line Terraform prints; a mismatch is flagged (a `replace` counts as one add + one destroy, matching how Terraform's own "Plan: N to add, M to change, K to destroy" line counts it)

Exits `0` if the tally matches; exits `1` if it doesn't (see below).

---

## Diff mode — verify against an expected shape

Pass a second argument: a small JSON file describing what the plan *should* contain:

```bash
python3 ai/claude/skills/iac-plan-verify/scripts/parse-tf-plan.py plan.jsonl expected-shape.json
```

`expected-shape.json`:

```json
{
  "resource_counts": {"aws_instance": 3},
  "must_include": ["aws_vpc.main"],
  "must_exclude": ["aws_nat_gateway.legacy"]
}
```

- `resource_counts` — exact expected count per `resource_type`; any deviation is flagged
- `must_include` — resource addresses (e.g. `aws_vpc.main`) that must appear somewhere in the plan
- `must_exclude` — resource addresses that must **not** appear (useful for catching a resource that should have been removed from the plan but wasn't, e.g. a decommissioned NAT gateway lingering in state)

All three keys are optional — include only the checks that matter for the plan being verified.

---

## Exit codes (usable as a gate, not just informational)

| Code | Meaning |
| --- | --- |
| `0` | Tally matches `change_summary`, and (if given) matches the expected shape |
| `1` | A mismatch was found — own tally vs `change_summary`, or a `resource_counts`/`must_include`/`must_exclude` violation |
| `2` | Usage or input error (bad arguments, unreadable file, invalid JSON in the expected-shape file) |

Wire this into a CI step or pre-apply check to hard-fail on an unexpected plan shape instead of relying on someone reading the output.

---

## Input robustness

Streamed Terraform JSON logs sometimes include stray non-JSON lines (progress output mixed in from a wrapping script, etc). The parser skips any line that fails to parse as JSON rather than crashing, and reports how many lines were skipped.

`apply_start`/`apply_complete` lines are tallied the same way as `planned_change` lines, so the same script works against `terraform apply -json` logs — useful for confirming what actually happened during apply, not just what was planned.
