---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: lra-access-key-remediation
description: Diagnoses a security-program ticket flagging an AWS IAM access key for rotation (LRA — long-running access — or similar 90-day-policy flags), and distinguishes an orphaned bootstrap key sitting behind a Vault AWS secrets-engine static role (which already auto-rotates, so the orphan should be deleted, not rotated) from a genuine rotation failure that needs an actual key rotation. Trigger on "access key rotation ticket", "IAM key flagged for rotation", "LRA finding", "key hasn't rotated in 90 days", "rotate this access key", "is this key an orphan", "static role vs rotation failure", or any ticket naming a specific IAM user/access-key-id with a rotation-policy violation. Hands off all cloud CLI verification and fix commands per this repo's cloud-cli-execution-ownership convention — never runs AWS/Vault CLI commands directly.
compatibility: Requires read access to the flagged ticket, infra repos containing Terraform/Vault config, and either direct or handed-off access to AWS CLI + Vault CLI per cloud-cli-execution-ownership.
---

# LRA Access Key Remediation

A security program periodically files tickets flagging an AWS IAM access key that hasn't rotated within policy. The reflexive fix — "rotate the key" — is often wrong: when the flagged user is backed by a Vault AWS secrets-engine **static role**, Vault already auto-rotates the key on its own schedule, and the flagged key is frequently an **orphaned bootstrap key** (unused, sitting at the IAM 2-key-per-user cap) blocking Vault's own rotation rather than a rotation failure. Deleting the orphan is usually the right fix, not rotating it. This skill runs that diagnosis before proposing a fix.

**This skill never runs cloud CLI commands directly.** Every verification and fix command below is hand-off text per `cloud-cli-execution-ownership` — read that skill first if execution ownership for this project/account hasn't already been established this session.

## 1. Parse the ticket

Extract from the flagged ticket:

- IAM user name (or access key ID, which you'll resolve to a user)
- AWS account ID / account alias
- The key's creation date and last-rotated date (if the ticket includes them)

Without at least the IAM user and account, there's nothing to diagnose — ask for these if missing.

## 2. Check whether the user is Vault-static-role-backed

Search infra repos for a Terraform `vault_aws_secret_backend_static_role` resource (or equivalent static-role mapping) whose `username` matches the flagged IAM user:

```bash
grep -rn "vault_aws_secret_backend_static_role" <infra-repo-path>
grep -rn "<flagged-iam-username>" <infra-repo-path>
```

- **No match found** → this is not a Vault-managed static role. Skip to Step 4 (genuine rotation failure path) — Vault has no rotation responsibility here, so any orphan-vs-failure distinction doesn't apply.
- **Match found** → note the Vault mount path and role name from the resource block, and continue to Step 3.

## 3. Compare Vault's active key against the IAM user's actual keys

Hand off these read-only checks (per `cloud-cli-execution-ownership` — a single read-only pass is fine before asking about execution ownership, per that skill's rule of thumb):

```bash
vault read <mount-path>/static-creds/<role-name>
aws iam list-access-keys --user-name <flagged-iam-username>
aws iam get-access-key-last-used --access-key-id <each-key-id>
```

Compare:

- Which access key ID does Vault's static-creds response report as currently active?
- Does the IAM user have a *second* key that Vault's response does not reference?
- What is that second key's `LastUsedDate` (empty/never-used is the strongest orphan signal) and creation date?

## 4. Decide: delete-orphan vs. rotate-stalled

- **Delete the orphan** when: the user is Vault-static-role-backed, Vault's static-creds reports one key as active, and the flagged key is the *other* key with no (or very old) last-used activity. The orphan is very likely a leftover bootstrap key blocking Vault's own rotation cycle (IAM's 2-key cap means Vault can't create a new key while an unused second key occupies the slot).
- **Genuine rotation failure** when: the user is not Vault-managed at all (Step 2 found no match), or the flagged key *is* the one Vault's static-creds reports as currently active but its age still exceeds policy (Vault's rotation is stalled or misconfigured) — this needs investigation into why Vault's rotation didn't fire, not a simple delete.
- If the evidence is ambiguous (e.g. both keys show recent activity), say so explicitly and do not guess — hand the ambiguity to the user rather than picking a side.

## 5. Hand off verification + fix commands

Per `cloud-cli-execution-ownership`, present the decision and the exact commands rather than running them:

- **Delete-orphan path**: `aws iam delete-access-key --user-name <user> --access-key-id <orphan-key-id>` — call out that this unblocks Vault's next rotation cycle.
- **Rotate-stalled path**: point to the Vault static-role rotation mechanism (`vault write -f <mount-path>/rotate-role/<role-name>` or the underlying rotation period config) rather than manually rotating the IAM key by hand, since a manually-rotated key will just drift from Vault's expected state again.

## 6. Ticket comment and close expectation

Draft a ticket comment stating the diagnosis (orphan vs. stalled), the evidence used (key IDs, last-used dates, Vault static-creds output), and the fix command handed off. Do not mark the ticket resolved until the user confirms the hand-off command was actually run — this skill diagnoses and drafts, it does not execute or auto-close.

## What this skill is not

- Not a cloud CLI executor — see `cloud-cli-execution-ownership` for the execution-mode convention this skill always defers to.
- Not a Vault static-role setup tool — it diagnoses an existing static role's key state, it doesn't create or reconfigure roles.
