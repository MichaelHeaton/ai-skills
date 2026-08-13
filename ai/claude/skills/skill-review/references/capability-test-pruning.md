---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
---

# Capability-test pruning checklist

Origin: a decision-council session (2026-07-31) weighing scheduled wholesale deletion of CLAUDE.md/skill content against this repo's existing `skill-review` mechanism. Verdict: reject a timer-based deletion ritual (it can't distinguish "compensation cruft" from hard-won, incident-specific "scar tissue"), and reject leaving `skill-review` unchanged (its existing audit is additive/consistency-focused, not the capability-relative test the deletion advice is actually built on). This checklist is the fix — extend the audit, don't replace it or run a parallel ritual.

## The capability test

For any line that reads like scaffolding rather than domain knowledge, ask: **would a strong model behave worse without this line?**

- **Yes** → keep it. It's either compensating for a real gap or encoding a lesson the model can't otherwise know.
- **No, a capable model would do this anyway** → candidate for pruning.
- **Unsure** → keep it. A wrong prune is more expensive than a redundant line; when in doubt, don't cut.

Apply this per line or tight block, not per section — a section can mix genuinely load-bearing content with dead weight.

## Delete categories (candidates for pruning)

Apply the capability test first; these categories describe *where* compensation cruft tends to accumulate, not an automatic cut:

- **Persona blocks** — "You are an expert X" framing that doesn't change behavior
- **Restated general knowledge** — instructions re-explaining something any capable model already knows (general git usage, common language syntax, well-known tool defaults)
- **Verification instructions with no incident behind them** — "double-check your work" / "be careful" scaffolding that isn't tied to a specific failure mode
- **Emphasis scaffolding** — ALL-CAPS, repeated bolding, or redundant "IMPORTANT" markers propping up an instruction that would hold without them
- **Cross-file duplication** — the same rule restated in two places instead of one linking to the other
- **Unverifiable conditionals** — "if the model seems confused, do X" style branches with no concrete trigger a reviewer could check
- **Unfollowed aspirational process** — a step nobody actually follows in practice (check session history/git log for evidence it's ever executed)

## Keep-exemptions (never cut on capability grounds)

These survive the capability test by definition — they aren't compensating for model weakness, they're carrying information the model has no other way to know:

- **Project-specific gotchas** — a documented failure mode from a real incident (e.g. the false-positive scenarios behind `check-concurrent-session.sh` or `agent-md-sync`'s overwrite bug). These are exactly the "scar tissue" a timer-based deletion pass would wrongly discard.
- **Personal/team opinions and conventions** — routing rules, naming preferences, output-format choices tied to how this user/team actually works, not to model capability at all

## Verdict format

Every flagged line gets an explicit verdict, not a pass/fail impression of the section it's in:

```
<quoted line or tight block>
Verdict: KEEP — <reason, e.g. "encodes the #290 overwrite incident">
Verdict: PRUNE — <reason, e.g. "restates general git behavior, no incident behind it">
```

A skill can come out of review with zero prunes — "audited, nothing cut" is a valid and expected outcome, not a failure to find something.

## Provenance

No new tagging or provenance convention is introduced by this checklist. Git history (blame, commit messages) is sufficient for why/when context on any existing committed instruction — don't add a parallel annotation system on top of it.
