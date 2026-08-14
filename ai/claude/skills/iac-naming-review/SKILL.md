---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: iac-naming-review
description: Check a new IaC-managed resource name against the repo's documented naming conventions before it ships, especially when the name originated from copying an existing ClickOps-created artifact or another ad hoc resource. Catches a copied name that embeds an identifier system (a DNS hostname, an account alias, an old tool's naming scheme) instead of following the repo's own convention. Use before finalizing any new Terraform/Ansible/Helm resource name, or when asked "check this resource name", "does this follow our naming convention", or "is this name okay to ship".
compatibility: Requires access to the repo's naming-convention documentation (a style guide, existing resource names as precedent, or a documented pattern).
---

# IaC Naming Review

Copying an existing resource's name as a starting point for a new one is a common, reasonable shortcut — but it silently carries forward whatever naming decisions the original made, good or bad. A name copied from a ClickOps-created artifact often embeds an identifier system (a public hostname, an account alias, a tool that's since been replaced) that was never a deliberate convention — it's just whatever the console auto-generated or whoever created it typed. Treating a copied name as "the fresh naming decision" instead of "the copied one" is the gap this check closes.

## 1. Identify the naming source

Before finalizing a new resource name, ask: is this name a fresh decision, or copied from an existing resource (ClickOps-created, or another ad hoc one in the repo)? If copied, that's the signal to run this check — a name written from scratch against the convention doesn't need it.

## 2. Find the repo's actual naming convention

Read the repo's documented naming convention (a style guide, a `CONVENTIONS.md`, a comment block in the module) if one exists. If none is documented, infer the pattern from 3–5 existing, clearly-deliberate resource names in the same category — not from the one resource being copied, which may itself be the exception.

## 3. Check the new name against it

Specifically check whether the new name embeds an identifier that doesn't belong in a resource name per the convention:

- A public DNS hostname where the convention expects an internal/logical identifier
- An account alias or subscription ID baked into the string
- A superseded tool or team name that's since been renamed
- Environment or region encoded in a place inconsistent with where the convention puts it

## 4. Flag or confirm

If the name doesn't match the convention, flag it before it ships — propose a corrected name following the actual convention, and note what the copied name would have carried forward if left as-is. If it does match, say so and move on; don't manufacture a finding to show the check ran.

```
⚠ Resource name `sql-server-prod.internal.corp.example` embeds a legacy internal
  hostname — repo convention is `<service>-<env>-<region>`. Suggest: `billing-prod-use1`.
```

## 5. If this recurs

A copied name that violates the convention once is a one-off catch. If the same pattern shows up repeatedly (several ClickOps artifacts all carrying the same legacy identifier system), that's worth a cleanup ticket covering the whole set, not a one-at-a-time fix each time a new resource copies from the same bad precedent.
