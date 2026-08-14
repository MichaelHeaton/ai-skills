---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: iac-recover
description: Diagnose and recover from a partial Terraform apply that left state and reality out of sync — resource exists in the provider but not in state, resource in state but gone from the provider, or a plan/apply divergence. Covers the import path (with correct address quoting) and the delete-and-recreate path, and when to prefer each. Use when a Terraform apply fails mid-run, when "terraform plan" shows an unexpected create/destroy for something that already exists, or when asked "how do I recover this Terraform state", "why does terraform want to recreate this", or "the apply died halfway through".
compatibility: Requires Terraform CLI access to the affected state.
---

# IaC Recover

A mid-apply failure leaves state and the real infrastructure disagreeing about what exists. Diagnosing which kind of disagreement it is comes first — the fix is different depending on direction.

## 1. Diagnose the failure mode from the error

| Symptom | Failure mode |
| --- | --- |
| `plan` wants to **create** something that already exists in the provider | Resource exists in provider, missing from state |
| `apply` fails with the resource already gone/deleted upstream | Resource in state, missing from provider |
| `plan` shows changes to fields nobody touched | Plan/apply divergence — provider-side drift, or a prior partial apply left state mid-transition |

## 2. Path A — Import (resource exists, state doesn't know)

```bash
terraform import 'aws_instance.web[0]' i-0123456789abcdef0
```

**Quote the resource address** when it includes brackets (`[0]`, `["key"]`) — an unquoted `resource.name[0]` gets interpreted by the shell before Terraform ever sees it, producing a confusing "resource not found" that has nothing to do with the resource actually being missing.

**Import can still fail with "not found" even when the resource genuinely exists.** Some providers read from a config/control-plane endpoint during import, not a direct existence check against the resource itself — a resource that exists but hasn't fully propagated to that endpoint, or lives in a different scope than the provider is configured for, produces a false "not found." Before concluding the resource is actually gone, verify existence through the provider's own console/API directly, independent of the import command's own error.

## 3. Path B — Delete-and-recreate (state says it exists, provider disagrees)

```bash
terraform state rm 'aws_instance.web[0]'
terraform apply
```

Prefer this over import when the resource is genuinely gone upstream and recreating it fresh is acceptable — import only makes sense when the real resource still exists and should be reconciled into state, not recreated.

**Before running `state rm`**, confirm the resource really is gone rather than assuming from the error alone — a transient API error can look identical to "resource doesn't exist," and `state rm` on a resource that's actually still there orphans it (Terraform loses track of something real).

## 4. Provider-specific quirks (examples, not exhaustive)

- **Vault auth backends**: the backend path and the resource's internal ID aren't the same string — importing by path alone can succeed while leaving config drift, because some backend settings live outside what import pulls in. Verify the full config, not just successful import, before trusting state.
- Check each provider's own import documentation for what it does and doesn't pull in — a successful import command doesn't guarantee full field parity with a fresh `apply`.

## 5. After recovery

Run `terraform plan` once more before considering the recovery done — a clean plan (no unexpected changes) is the actual confirmation that state and reality agree again, not just that the import/state-rm command exited zero.
