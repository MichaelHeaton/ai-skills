---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-10
updated_by: claude
---

# Audience-leak patterns: before/after

Worked examples for each checklist category in [SKILL.md](../SKILL.md). Names below are generic placeholders standing in for whatever internal tool, bot, or codename actually shows up in a real draft.

## Conversational residue

**Before:**
> ⚠️ Not the bot you might be thinking of — this is a separate thing.

This only makes sense as a reply to an unstated question ("wait, is this the other one?"). A reader landing on the page cold has no idea what "the one you're thinking of" refers to, so the warning reads as noise, or worse, as a sign something's being withheld.

**After:**
> ProjectName is an internal service for [what it does]. It is unrelated to OtherTool, a separate [what that other thing is] used by [team/purpose] — the two share no code or data.

The fix isn't to soften the warning, it's to replace the implicit question with an explicit, self-contained statement. If the distinction genuinely doesn't matter to this page's audience, cut it entirely instead.

## Unintroduced references

**Before:**
> Unlike OtherBot, there is no separate web chat portal for this instance.

Useful contrast, zero introduction. A reader who has never heard of "OtherBot" gets a comparison to nothing.

**After (keep the name, add the explanation):**
> Unlike OtherBot — [team]'s separate assistant, which has its own web chat UI — this instance only works inside [surface]. There's no separate portal to visit.

**After (drop the name, keep the property):**
> This instance only works inside [surface]; there's no separate web portal to visit.

Pick whichever serves the reader better: name-and-explain when the comparison itself is informative, drop-the-name when the other tool doesn't matter to this reader at all.

## Q&A-order structure

**Before:** a page opens with "Does it store history?" → "Is it region-locked?" → "How do I integrate it?" → "What is it?" — because that's the order the questions came up in chat.

**After:** What it is → why it exists / what it's for → how to use or integrate it → limitations and edge cases (storage, availability, etc.). A reader needs orientation before detail, regardless of what order the original conversation covered things.

## Assumed shared context

**Before:**
> As discussed, the new limit applies to all instances created after the migration.

"As discussed" with whom? A reader who wasn't in that discussion has no way to know what changed, when, or why "the migration" is a fixed point they're expected to already know about.

**After:**
> Starting [date/event], new instances are subject to a [limit]. Instances created before that date are unaffected.

State the fact on its own terms; don't gesture at a conversation the reader wasn't part of.

## Missing orientation

**Before:** a page's first line is a caveat, a warning, or a config table — no sentence establishing what the page even documents.

**After:** open with one or two sentences: what this is, and why someone would be reading this page. Everything else — caveats included — comes after the reader knows what they're looking at.
