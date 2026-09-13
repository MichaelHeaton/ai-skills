---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-13
updated_by: claude
---

# Engineering practices

## Purpose

Day-to-day checklist form of the engineering philosophy this workspace assumes. The reasoning and case studies behind each line live in the maintainer's personal knowledge base — this file is the portable, domain-agnostic version, one line per principle, phrased as a drift check rather than a lecture.

## Checklist

- **Rule of Two — verification before action, not headcount.** No single actor (human or AI) merges or deploys on its own unverified claim. The independent second check can be another person, another AI, or a test suite that's earned enough trust to stand in for one — auto-merge is legitimate once it has; a manual merge with no independent second isn't, no matter who clicks it.
- **DRY — single source of truth.** Before a fact gets a second home, ask which one wins when they disagree. No instant answer means two sources of truth, not one.
- **IaC — no config that isn't committed.** A change made by hand that would be lost on rebuild doesn't exist yet.
- **GitOps — merge is the apply button.** Running the deploy command by hand instead of merging is a sign the pipeline doesn't cover this case — worth fixing, not routing around.
- **Monitor-first (the infra shape of TDD) — red before green.** A capability's failure state should be visible before the capability ships. If the first sign something broke is a person saying so, the monitor came after the deploy, not before.
- **DevSecOps — shift security left.** Disabling a control to unblock something can be the right call — but only with a linked ticket (owner, reason, revert-by date) in the same change. Without one, "temporary" becomes permanent, and the eventual fix is a bolted-on compensating control instead of the real one.
- **The Three Ways — flow, feedback, learning.** Keep work-in-process visible and bounded (flow); catch problems at the point of change, not downstream (feedback); when a decision changes, write down why, so a future re-check starts from "what changed" instead of from zero (learning).
- **One ticket, one owner.** A tracked unit of work belongs to exactly one parent. Two owners for the same outcome is a coordination bug waiting to surface as silent drift.
- **Decisions get a durable record, not just a memory.** Before re-deriving a settled decision from scratch, check for a record of the original reasoning. If none exists, write it now rather than after the next time it comes up.

## Related

- [core.md](core.md) — source-of-truth layering for this repo itself
- [security.md](security.md) — commit hygiene (different scope: what never goes in git, not how decisions get made)
