---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: k8s-volume-incident
description: Fast-path diagnosis and recovery for a stale NFS/virtiofs mount cascading into EMFILE errors, CrashLoopBackOff, and Argo CD selfHeal fighting a scale-to-0 remediation attempt. Use for "too many open files" / EMFILE, a stale or unresponsive shared mount (NFS, virtiofs, CIFS), CrashLoopBackOff after a host/VM reboot or storage hiccup, or Argo CD reverting a manual scale-down meant to unstick a wedged pod. Trigger phrases: "stale mount", "EMFILE", "too many open files", "virtiofs", "NFS stuck", "CrashLoopBackOff after reboot", "selfHeal keeps reverting my scale down", "volume stuck". Fast, single-incident path only — for a multi-hour investigation with unclear root cause, or a rehearsal/migration spanning multiple sittings, use infra-rehearsal-session instead. Complements incident-capture (post-mortem) and iac-triage (if the fix needs a Terraform/manifest change).
compatibility: Requires kubectl access to the affected cluster and Argo CD CLI or UI access to suspend sync.
---

# K8s Volume Incident

Fast-path recovery for the stale-mount → EMFILE → CrashLoop → selfHeal-fights-you incident signature. This is the short, mechanical version of the problem — diagnose the layer, stop Argo from undoing the fix, remount, verify. If root cause is unclear after Step 1, or the incident spans multiple sittings, hand off to `infra-rehearsal-session` instead of continuing here.

## Why this exists, distinct from infra-rehearsal-session

`infra-rehearsal-session` is built for multi-day rebuilds and hypothesis-by-hypothesis investigation with a running plan doc. This incident signature is usually resolved in minutes once recognized — writing a plan doc for it is overhead, not discipline. This skill exists to short-circuit straight to the fix once the signature matches, and to explicitly hand off to the heavier skill only if that fast path fails.

## Step 1 — Confirm the signature

Check for all three symptoms before proceeding — a partial match may be a different failure class:

- **Stale mount at the volume layer**: `kubectl exec` into the pod (or a debug pod on the same node) and try `ls` on the mounted path. A hang, or `stat: Stale file handle`, confirms a stale NFS/virtiofs mount rather than an application bug.
- **EMFILE in logs**: `kubectl logs <pod> --previous | grep -i "too many open files\|EMFILE"`. This is the downstream symptom of the stale mount — the app leaks file descriptors trying to retry against a dead mount.
- **CrashLoopBackOff**: `kubectl get pods -A | grep CrashLoop`. Confirms the pod is actively cycling rather than just degraded.

If only one or two of these are present, treat it as a different incident and do not proceed on this fast path.

## Step 2 — Suspend Argo CD automated sync FIRST

**⚠️ Do this before any remount, evict, or restart.** If Argo CD selfHeal is active on the affected Application, it will revert a manual scale-to-0 (or any other direct fix) back to the declared spec while you're mid-remediation — this looks like the fix silently failing and burns time re-diagnosing a problem that's already solved.

```bash
argocd app set <app-name> --sync-policy none
```

Or via `kubectl` if the Argo CLI isn't available:

```bash
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"spec":{"syncPolicy":null}}'
```

Confirm the patch took before continuing — check the Application's `spec.syncPolicy` is empty/null, not just that the command exited 0.

## Step 3 — Remount / evict / restart

With sync suspended, the direct intervention will stick:

1. **Scale the affected workload to 0** to release the stale mount's file handles: `kubectl scale deployment/<name> --replicas=0`.
2. **Evict or restart the node-level mount** if the stale handle is host-side (common with virtiofs on a VM host) — this typically means unmounting and remounting the share on the hypervisor/host, not inside the pod. Confirm with whoever owns the host layer before running host-level commands from here.
3. **Scale back up**: `kubectl scale deployment/<name> --replicas=<original>`.
4. Watch the pod come up clean: `kubectl get pods -w`.

## Step 4 — Verify

- Pod is `Running` and stable (no restart count increase over a few minutes' watch).
- `ls` on the mount path from inside the pod returns cleanly, no stale-handle error.
- Logs show no further EMFILE errors: `kubectl logs <pod> -f | grep -i EMFILE` (expect nothing).

## Step 5 — Re-enable Argo sync

Only after verification passes — re-enabling early risks selfHeal reverting a still-in-progress fix:

```bash
argocd app set <app-name> --sync-policy automated --self-heal
```

Confirm the next sync reconciles cleanly rather than immediately flapping.

## When this fast path doesn't resolve it

If the mount restabilizes but the pod immediately re-crashes, or the stale-mount cause itself is unclear (host storage failure, network partition, hypervisor issue), stop and hand off to `infra-rehearsal-session` — this is now a multi-hypothesis investigation, not a known-signature fast path. Bring what you've already ruled out in Steps 1–4 as the starting "Ruled out" section of that skill's plan doc, so the investigation doesn't repeat this diagnosis.

Once resolved, use `incident-capture` for the post-mortem.
