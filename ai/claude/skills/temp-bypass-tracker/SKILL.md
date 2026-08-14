---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: temp-bypass-tracker
description: Mark and track a temporary security bypass or config deviation introduced to unblock work — a disabled TLS check, a skipped validation, a hardcoded credential placeholder — so it's tied to the ticket(s) that will let it be reverted instead of quietly becoming permanent. Use whenever introducing any interim workaround that weakens a check or deviates from normal config, or when asked "track this as a temporary bypass", "how do I flag this as interim", or "make sure we don't forget to revert this".
compatibility: None — works with any codebase's comment/PR conventions.
---

# Temp Bypass Tracker

An interim bypass introduced under time pressure ("skip TLS verification until the cert fix lands") is easy to justify in the moment and easy to forget about once the immediate pressure is gone. This gives it a consistent, minimal tracking pattern instead of an ad hoc comment that only the original author remembers to check on.

## 1. Mark it in code

At the exact point of the bypass, add a comment with a fixed shape:

```python
# TEMP-BYPASS: TLS verification disabled — blocked on cert/DNS fix.
# Revert when: #142 and #145 both land.
# Introduced: 2026-08-14
verify=False
```

Keep the marker (`TEMP-BYPASS:`) consistent across the codebase — it's what makes the bypass greppable later (`grep -r "TEMP-BYPASS:"`) without relying on anyone remembering where they all are.

## 2. Reference it in the PR description

Add a line under a `## Temporary bypasses` heading (create it if the PR doesn't have one) naming the bypass and the ticket(s) that revert it — don't bury it only in the inline code comment, since a PR reviewer scanning the description should see it without having to find the exact line in the diff.

## 3. Track the reverting ticket(s)

If the ticket(s) that will let this be reverted don't already reference the bypass, add a comment on each linking back to the file/line and PR that introduced it — this closes the loop in both directions: the code points at the ticket, the ticket points at the code.

## 4. Periodic sweep (optional, for accumulated bypasses)

```bash
grep -rn "TEMP-BYPASS:" --include="*.tf" --include="*.py" --include="*.go" .
```

Run this periodically (or as part of a repo-hygiene pass) to surface every still-active bypass in one list — cross-check each against its named reverting ticket's current status. A bypass whose reverting ticket already closed and wasn't actually reverted is the failure mode this whole pattern exists to prevent.

## 5. Reverting

When the reverting ticket(s) land, remove the bypass and its marker comment in the same PR that fixes the underlying blocker — don't leave the marker in place "just in case."
