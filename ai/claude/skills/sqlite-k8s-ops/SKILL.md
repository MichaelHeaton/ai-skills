---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: sqlite-k8s-ops
description: Production SQLite backup and restore procedure for a database running inside Kubernetes — WAL checkpoint, extract via kubectl cp, integrity and row-count verification, restore, restart. Commands are front-loaded so approval friction is minimized mid-incident. Use when a SQLite-backed pod needs a backup before a risky change, a restore after corruption or data loss, "sqlite restore", "database backup failing", "WAL checkpoint", "kubectl cp sqlite", or when Argo CD selfHeal is fighting a restore in progress (same pause-first principle as k8s-volume-incident). Complements k8s-volume-incident (volume-layer incidents) and infra-rehearsal-session (if the restore path is unclear and needs multi-hypothesis investigation).
compatibility: Requires kubectl access to the affected cluster and sqlite3 CLI on either the pod or a local machine with the extracted file.
---

# SQLite K8s Ops

Backup and restore procedure for a production SQLite database running inside a Kubernetes pod. Commands are given up front, in the order you'll actually run them, so a live incident doesn't stall on figuring out syntax mid-restore.

## Why front-loaded commands matter here

A SQLite restore under time pressure is exactly when someone re-derives `kubectl cp` syntax from memory and gets it wrong. This skill exists to remove that friction — every command below is copy-pasteable in sequence, with the pause-first-for-Argo step called out before anything else so it isn't skipped when moving fast.

## Backup procedure

### Step 1 — WAL checkpoint before extracting

**⚠️ Skipping this risks extracting a database file with uncommitted WAL data missing** — the `.db` file alone is not a consistent snapshot while a WAL file exists alongside it.

```bash
kubectl exec <pod> -- sqlite3 /path/to/db.sqlite "PRAGMA wal_checkpoint(TRUNCATE);"
```

Confirm the output shows `0` in the first column (no busy checkpoint blocked by a live writer) before proceeding.

### Step 2 — Extract the file

```bash
kubectl cp <namespace>/<pod>:/path/to/db.sqlite ./db-backup-$(date +%Y%m%d-%H%M%S).sqlite
```

### Step 3 — Verify the extracted backup

Run both checks — integrity alone can pass on a truncated file with a valid header:

```bash
sqlite3 ./db-backup-*.sqlite "PRAGMA integrity_check;"
sqlite3 ./db-backup-*.sqlite "SELECT count(*) FROM <primary_table>;"
```

Compare the row count against a known-good expectation (previous backup's count, or an approximate range) — a suspiciously low count means the checkpoint or copy happened mid-write.

## Restore procedure

### Step 1 — Suspend Argo CD automated sync FIRST

**⚠️ Do this before touching the pod.** If Argo selfHeal is active on the Application managing this workload, it can restart or reschedule the pod mid-restore, clobbering a partially-written file or racing your restart in Step 4. This mirrors the same pause-first principle `k8s-volume-incident` uses for volume remediation.

```bash
argocd app set <app-name> --sync-policy none
```

Confirm `spec.syncPolicy` is empty before continuing:

```bash
kubectl get application <app-name> -n argocd -o jsonpath='{.spec.syncPolicy}'
```

### Step 2 — Scale down the consumer

```bash
kubectl scale deployment/<name> --replicas=0
```

A SQLite file being written to while you overwrite it underneath is worse than a few minutes of downtime.

### Step 3 — Copy the restore file in

```bash
kubectl cp ./db-restore.sqlite <namespace>/<pod>:/path/to/db.sqlite
```

If the pod is already scaled to 0, you may need a temporary debug pod mounting the same volume instead — use whichever mounts the same PVC.

### Step 4 — Scale back up and verify

```bash
kubectl scale deployment/<name> --replicas=<original>
kubectl exec <pod> -- sqlite3 /path/to/db.sqlite "PRAGMA integrity_check;"
kubectl exec <pod> -- sqlite3 /path/to/db.sqlite "SELECT count(*) FROM <primary_table>;"
```

Confirm the row count matches what was in the restored file, and the application comes up without errors referencing the database.

### Step 5 — Re-enable Argo sync

Only after verification passes:

```bash
argocd app set <app-name> --sync-policy automated --self-heal
```

## If this doesn't resolve cleanly

If the restore file itself is suspect (failed integrity check, unexpected row counts with no clear cause), or the corruption's root cause is unclear, stop and hand off to `infra-rehearsal-session` for a structured multi-hypothesis investigation rather than repeating restore attempts against an unknown failure mode.
