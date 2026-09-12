---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: github-actions-oidc
description: Diagnose and fix GitHub Actions OIDC AssumeRoleWithWebIdentity denials against AWS IAM, especially when a workflow job sets `environment:` and the trust policy was written for the unscoped subject. Trigger on "sts:AssumeRoleWithWebIdentity" errors, "Not authorized to perform sts:AssumeRoleWithWebIdentity", "OIDC AssumeRole failed", "GitHub Actions can't assume the role", "deploy role trust policy doesn't match", "sub claim mismatch", "webidentity denied", or a pasted GitHub Actions OIDC failure plus an optional CloudTrail event. Explains that a job with `environment: NAME` sends `repo:ORG/REPO:environment:NAME`, not the unscoped `pull_request` or `ref:refs/heads/...` subjects, and fixes the IAM trust policy (and Terraform `github_environments` name) to match. Complements iac-triage and iac-reviewer — use this for OIDC sub-claim mismatches specifically, not general Terraform triage.
compatibility: Requires AWS CLI access to CloudTrail (or equivalent console access) to read the denied AssumeRoleWithWebIdentity event. Cloud-compatible — no local-machine-only paths or tooling.
---

# GitHub Actions OIDC AssumeRole Failures

A GitHub Actions job authenticating to AWS via OIDC fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity` when the IAM role's trust policy condition doesn't match the `sub` claim GitHub actually sent. The most common cause: the trust policy was written for a plain `pull_request` or branch-ref subject, but the failing job runs under a GitHub **Environment** (`environment: NAME`), which sends a different `sub` shape entirely.

## 1. Read the actual `sub` claim from CloudTrail — don't guess

Guessing the `sub` pattern from the workflow YAML alone is unreliable — trigger type, environment, and ref all change its shape. Find the real value from the denied event:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-results 10
```

Filter to the denied event around the failure timestamp and inspect its `requestParameters` / `errorMessage` for the `sub` and `aud` values GitHub's token actually presented. If CLI access isn't available, pull the same event from the CloudTrail console (Event history, filtered to `AssumeRoleWithWebIdentity`).

**Don't skip this step even if the fix "looks obvious"** — the point is to confirm the exact string the trust policy needs, not to pattern-match from memory.

## 2. Know the subject shapes GitHub sends

GitHub's OIDC token `sub` claim depends on how the job is triggered:

| Job configuration | `sub` claim |
| --- | --- |
| No `environment:`, triggered by `pull_request` | `repo:ORG/REPO:pull_request` |
| No `environment:`, triggered by branch push | `repo:ORG/REPO:ref:refs/heads/BRANCH` |
| Job sets `environment: NAME` | `repo:ORG/REPO:environment:NAME` |

**The key fact this skill exists for**: adding `environment:` to a job changes its `sub` to the `environment:NAME` form — it does **not** additionally send the unscoped `pull_request` or `ref:` subject. A trust policy that only allows `repo:ORG/REPO:pull_request` will deny every job that runs under an Environment, even from the same repo and the same triggering event.

Use placeholders (`ORG`, `REPO`, `NAME`, account `123456789012`) in any example you write or paste elsewhere — never real org/account values, per this repo's public-repo content-caution rule.

## 3. Fix the trust policy condition

The IAM role's trust policy `Condition` must include the exact `sub` pattern from Step 1, and the correct `aud` — typically `sts.amazonaws.com` for GitHub's default audience:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:environment:NAME"
    }
  }
}
```

Add the `environment:NAME` pattern alongside (not instead of) any other subject the role legitimately needs — a role that also runs non-environment jobs should keep both `StringLike` values as a list.

## 4. If Terraform-managed, match the Environment name exactly

When the trust policy or the GitHub Environment itself is provisioned via Terraform (e.g. a `github_repository_environment` / `github_environments` resource), the environment name configured there must **exactly match, case-sensitively**, the Environment name configured in the GitHub repo's Settings → Environments. A mismatch here (`Production` vs `production`) produces the same denial even after Step 3's trust policy edit, because GitHub sends the `sub` using the actual configured Environment name, not Terraform's.

Confirm both sides read the same string before considering the fix verified — check the GitHub repo settings against the Terraform resource, not just the Terraform source against itself.

## Verify the fix

Re-run the failing job (or push a no-op commit) and confirm the `sts:AssumeRoleWithWebIdentity` call succeeds. If it still fails, re-run Step 1 against the new denied event — a second mismatch (wrong `aud`, a typo in `ORG/REPO`, or a second Environment name not yet added) is more likely than the same fix needing to be reapplied.

## Relationship to iac-triage / iac-reviewer

**`iac-triage`** covers general Terraform/Ansible/Kubernetes/CI evidence-ordering discipline — use it for the "what's the smallest useful slice of a failing plan or log to look at" problem. **`iac-reviewer`** reviews a Terraform plan for risk before `apply`. Neither encodes the GitHub OIDC `sub`-claim shape — this skill is the narrow, standalone fix for that specific failure signature and is meant to be invoked directly rather than folded into either.
