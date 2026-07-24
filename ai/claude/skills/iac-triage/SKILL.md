---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: iac-triage
description: SRE / IaC investigation mode for Terraform, Ansible, Kubernetes, CI/CD, and incident log work. Encodes evidence ordering (ask for the smallest useful slice first, not full output), hypothesis-driven questioning, and a structured triage response format. Prevents context overload from full plan dumps, verbose Ansible runs, and raw log pastes. Trigger on: any Terraform, Ansible, or kubectl investigation; "debug this plan", "ansible failed", "k8s error", "CI is failing", "deployment failed", "investigate this incident", "triage this", "terraform error", "playbook failing", "pipeline broken", or any time raw operational output is about to be loaded into context.
compatibility: Any repo or workspace. Integrates with log-clip / clog if installed.
---

# IaC Triage Mode

Raw CLI output is hostile to context. A full `terraform apply` or `ansible-playbook -vvv` run can be 2000+ lines; the signal is usually under 20. Your job is to diagnose infrastructure failures with the smallest useful evidence set.

**Default posture: ask for evidence slices, not full output.**

---

## Evidence ordering (never ask for full output first)

**Terraform**

1. Exact error block
2. Affected resource(s) + module path
3. Workspace / environment / backend
4. Resource diff (`terraform plan -target=<resource>`)
5. Full plan — only if steps 1–4 didn't resolve it

**Ansible**

1. Failed task name
2. Module + target host/group
3. stderr/stdout from the failed task only
4. 20 lines of surrounding task context
5. Verbose output — only if task evidence is insufficient

**Kubernetes / cloud CLI**

1. Error signature (pod status, event type, reason)
2. Narrow time window (last 15–30 min)
3. One representative failure block
4. Namespace / pod / container context
5. Full event stream — only if pattern is still ambiguous

**CI/CD**

1. Failed step name + exit code
2. Command that failed
3. Last 100–300 relevant lines
4. Full log — only if failure location is unknown

**Incident / general logs**

1. First failing signal + timestamp
2. Repeated error signature (pattern, not all instances)
3. Narrow time window around first and last failure
4. Raw dump — only for genuinely unresolved ambiguity

---

## Operationally useful questions

When evidence is incomplete, ask for the **smallest high-value detail**:

- "Which resource actually changed?"
- "Which task failed first?"
- "Was this plan against dev, stage, or prod?"
- "Is this auth, path, idempotency, or state drift?"
- "Do you have the stderr from the failing task specifically?"
- "Show me the last 200 relevant lines — not the whole run."

Do not ask broad abstract questions. A concrete operational detail unblocks faster.

---

## Stop log spread

Do not keep widening the investigation without a reason.

- Current evidence supports a hypothesis → state it and propose a fix
- Need one more slice → name exactly which slice and why
- Never request "more logs" — request a **specific slice with a stated reason**

**Dimensions for chunking large output:** failing task · failing resource · pipeline step · host · container/pod · timestamp window · environment · stderr only

---

## Hypothesis before more evidence

Before requesting additional output, state the current hypothesis:

> "The error suggests a provider auth issue. Let me check X first. If that confirms it, the fix is Y."

If the hypothesis is testable with what you have → test it.
If not → request the smallest slice that would confirm or deny it.

---

## Triage response format

Always structure operational output analysis as:

1. **What failed** — one sentence
2. **Primary evidence** — the specific lines that matter
3. **Most likely cause(s)** — ranked, not exhaustive
4. **Missing evidence** — what would confirm the diagnosis
5. **Next exact slice** — precisely what to fetch (if still needed)
6. **Next remediation step** — one concrete action

---

## Session hygiene for ops work

| Situation | Action |
| --- | --- |
| Same incident, thread getting long | `/compact` |
| New incident / new environment / new failure class | Fresh session |
| Repeated troubleshooting pattern | Suggest converting to runbook, skill, or helper script |

Operational threads drift fast. Stale hypotheses from 30 messages ago cost tokens and are usually wrong.

---

## clog integration

If clog is installed (`~/.local/bin/clog`), direct the user to filter before pasting:

```bash
terraform apply 2>&1 | clog tf       # saves to ~/.claude/logs/tf-<timestamp>.log
ansible-playbook ... 2>&1 | clog ansible
kubectl apply -f . 2>&1 | clog k8s
```

Then read the filtered file — not the raw output:

```bash
ls -t ~/.claude/logs/tf-*.log | head -1
```

If clog isn't available, apply the evidence ordering above to manually request the right slice.
