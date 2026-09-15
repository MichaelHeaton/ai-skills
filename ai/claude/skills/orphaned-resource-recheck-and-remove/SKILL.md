---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: orphaned-resource-recheck-and-remove
description: Generate a paired recheck + phased-removal script scaffold for a stale ticket describing orphaned cloud resources (unused VPCs, security groups, IAM roles, KMS keys, snapshots, etc.). The recheck script is read-only and confirms current existence/state and dependency order; the removal script is dry-run by default, requires an explicit --execute flag plus a typed confirmation before any destructive call, and redacts credential-shaped values from all output. Use when asked to "clean up orphaned resources", "write a teardown script for these old resources", "recheck this stale cleanup ticket", "generate a removal script for [account/VPC/etc.]", or when a ticket lists AWS/cloud resources flagged for deletion and needs a safe script rather than a manual checklist. Produces real, runnable bash/python scripts, not just documentation.
compatibility: Requires cloud CLI access for the affected provider (aws, gcloud, az) and a shell with bash 4+ or Python 3.
---

# Orphaned Resource Recheck and Remove

Stale cleanup tickets go cold: by the time anyone acts on them, resource state may have drifted. Never delete straight from a ticket's original list — regenerate current truth first, then remove in dependency order, dry-run by default.

## When to use

A ticket names specific cloud resources (by ID, ARN, or name) as orphaned/unused and asks for cleanup, and the ticket is more than a few days old or its authorship is unclear. This pattern was built from scratch twice in one session for two separate stale AWS cleanup tickets — this skill exists so the third time is a template fill-in, not a rebuild.

## Step 1 — Extract the resource list and dependency order

Read the ticket and list every flagged resource with its type and identifier (e.g. `sg-0123abc` security group, `vpc-0456def` VPC, IAM role ARN, KMS key ID). Establish teardown order by dependency, not ticket order — the removal script depends on getting this right:

1. Instances / ENIs attached to the resources
2. Security group rules referencing other flagged groups
3. Security groups
4. Subnets
5. Route tables / NAT gateways / internet gateways
6. VPC
7. IAM roles/policies (only after nothing still assumes them)
8. KMS keys (schedule deletion last — it's the hardest to undo)

## Step 2 — Generate the redact() helper

Every script (recheck and removal) shares this helper. Write it once, source or duplicate it into both scripts:

```bash
redact() {
  # Masks credential-shaped values so output stays safe to paste into chat/tickets.
  sed -E \
    -e 's/AKIA[0-9A-Z]{16}/AKIA****************/g' \
    -e 's/(aws_secret_access_key *= *)[A-Za-z0-9\/+=]{40}/\1****REDACTED****/g' \
    -e 's/arn:aws:iam::[0-9]{12}:/arn:aws:iam::************:/g' \
    -e 's/[0-9]{12}/************/g'
}
```

Pipe every command's stdout/stderr through `redact` before printing or logging: `some-command 2>&1 | redact`.

## Step 3 — Write the recheck script (`scripts/recheck.sh`)

Read-only. For each flagged resource, in dependency order, confirm it still exists and capture its current state and attachments:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/redact.sh"

echo "=== Recheck: $(date -u +%FT%TZ) ===" | redact

check_sg() {
  local sg_id="$1"
  aws ec2 describe-security-groups --group-ids "$sg_id" 2>&1 | redact || \
    echo "GONE: $sg_id no longer exists" | redact
}

check_vpc() {
  local vpc_id="$1"
  aws ec2 describe-vpcs --vpc-ids "$vpc_id" 2>&1 | redact || \
    echo "GONE: $vpc_id no longer exists" | redact
  echo "-- dependents --"
  aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" 2>&1 | redact
}

# Fill in one check_* call per resource from Step 1, in dependency order.
# check_sg "sg-0123abc"
# check_vpc "vpc-0456def"

echo "=== Recheck complete — review output above before running removal.sh ===" | redact
```

Extend with `check_iam_role`, `check_kms_key`, etc. following the same shape: try the read call, fall back to a `GONE:` line, redact everything.

## Step 4 — Write the removal script (`scripts/removal.sh`)

Dry-run by default. Requires `--execute` **and** a typed confirmation before any destructive call runs:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/redact.sh"

EXECUTE=false
[[ "${1:-}" == "--execute" ]] && EXECUTE=true

run_or_echo() {
  local desc="$1"; shift
  if [[ "$EXECUTE" == "false" ]]; then
    echo "[DRY-RUN] would run: $desc" | redact
  else
    echo "[EXECUTE] $desc" | redact
    "$@" 2>&1 | redact
  fi
}

if [[ "$EXECUTE" == "true" ]]; then
  echo "About to run DESTRUCTIVE removal against the resources listed below."
  echo "Type the ticket number to confirm (e.g. 534):"
  read -r confirm
  if [[ "$confirm" != "534" ]]; then
    echo "Confirmation mismatch — aborting." | redact
    exit 1
  fi
fi

# Phase order must match Step 1's dependency order, reversed for teardown
# where the ticket adds resources on top of shared ones.

# Phase 1: security group rules / detach ENIs
run_or_echo "revoke sg rule on sg-0123abc" aws ec2 revoke-security-group-ingress --group-id sg-0123abc ...

# Phase 2: security groups
run_or_echo "delete sg-0123abc" aws ec2 delete-security-group --group-id sg-0123abc

# Phase N: VPC (near-last)
run_or_echo "delete vpc-0456def" aws ec2 delete-vpc --vpc-id vpc-0456def

# Phase last: KMS key (schedule deletion, never immediate)
run_or_echo "schedule-key-deletion for key-id" aws kms schedule-key-deletion --key-id KEY_ID --pending-window-in-days 30
```

Fill in one `run_or_echo` call per resource, ordered per Step 1. Never call a delete API directly outside `run_or_echo` — that's what keeps dry-run authoritative.

## Step 5 — Get stakeholder sign-off before `--execute`

Before anyone runs `removal.sh --execute`:

1. Run `recheck.sh`, paste its (already-redacted) output into the ticket as a comment.
2. Run `removal.sh` in dry-run mode (no flags), paste that output into the ticket too — it shows exactly what will happen.
3. Ask the ticket owner or stakeholder to record explicit sign-off as a ticket comment (e.g. "Reviewed dry-run output, approved for execute").
4. Only after sign-off is visible on the ticket, run `removal.sh --execute` and type the confirmation string when prompted.

**⚠️ Never run `--execute` without a recorded sign-off comment on the ticket** — the typed confirmation prevents an accidental flag, not an unapproved one.

## Step 6 — Verify and close out

After execution, re-run `recheck.sh` — every resource should report `GONE`. Paste that final output on the ticket as closure evidence, then close the ticket (see `issue-update`).
