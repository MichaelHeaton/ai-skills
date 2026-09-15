# Unattended dry-run (no live user present)

**When this applies**: `skill-create` is invoked with no live user turn to answer — "share test prompts, wait for review" (Step 6) and "review the set with the user" (Step 8) can't happen. The concrete trigger case: `dev-team`'s Architect hands off a `type/new-skill` ticket to `skill-create` during an unattended/scheduled `backlog-burndown` run. Same no-user signal `backlog-burndown` itself uses for its own unattended-run handling.

**Do not skip Steps 6 and 8 outright** the way past unattended runs did — several merged PRs (ai-skills#847, #848, #849, #772, #799, #562) shipped with "skill-create's normal live interview was skipped" and no testing at all, just a bare "needs interview" note. That's the gap this reference closes: a scaled-down, non-interactive version of Steps 6 and 8 that produces a graded verdict instead of silence.

## 1. Generate prompts (scaled down for cost)

- **3 realistic test prompts** (Step 6's own criteria: specific, varied phrasing, edge-case-leaning) — same count as the interactive path, no change needed there.
- **3 should-trigger + 3 should-not-trigger (near-miss) prompts** instead of Step 8's interactive 8–10 — enough to catch the common failure (too narrow or too broad) without paying full price unattended. Use 8–10 instead if the ticket or the skill's own risk profile calls for extra care.

## 2. Trigger-correctness check

Dispatch each of the 6 trigger prompts to a **fresh Agent-tool subagent** (`general-purpose`, read-only judgment call — no worktree isolation needed) told:

> Here is a candidate skill's description: `<paste>`. Here are 2–3 other already-installed skills' descriptions, for realistic competition: `<paste>`. Given this user message: "`<prompt>`", would you invoke the candidate skill? Answer only yes/no and one sentence why.

Compare against expectation:

- Should-trigger prompt answered "no" → **trigger too narrow**.
- Should-not-trigger prompt answered "yes" → **trigger too broad** — the more dangerous direction, since an over-eager skill fires on the wrong task with no one there to redirect it.

## 3. Behavioral-correctness check

For the 3 test prompts, dispatch a **fresh Agent-tool subagent** per prompt with the candidate skill's full `SKILL.md` body pasted directly into its prompt (it can't be dispatched via the `Skill` tool before install — Step 6's existing note on this still applies) and explicit instructions:

> Follow these instructions to handle this request: "`<prompt>`". This is a dry run — do not take any real write action (no real `gh`/git/file-system writes, no real API calls with side effects). Narrate each step you would take and its expected result instead, and stop before any action that isn't purely observable.

Read the resulting transcript against the skill's own documented steps: did it skip a documented step, misread an instruction, or do something the skill explicitly says not to do?

**Never let the dry run itself cause a real side effect.** The "narrate, don't execute" instruction above is the safety boundary — a badly-drafted skill that dry-runs into "delete the repo" must produce a narrated line describing that, not an actual `rm`.

## 4. Grade and report

```text
## Dry-run verification (unattended)
- Should-trigger: <n>/3 matched
- Should-not-trigger: <n>/3 correctly declined
- Test prompts: <n>/3 produced expected behavior — <one line per miss>
- Verdict: READY FOR HUMAN REVIEW | NEEDS REWORK
```

All 6 trigger checks correct **and** all 3 test prompts behaved as documented → `READY FOR HUMAN REVIEW`. Anything else → `NEEDS REWORK`.

## 5. On `NEEDS REWORK` — one revision pass, then stop

Apply Step 7's revise-based-on-feedback using the specific miss as feedback, then re-run this dry-run once. **Hard cap at one retry** — same pattern as `dev-team`'s resume-attempt cap. If still failing after the retry, open the PR anyway rather than blocking the ticket indefinitely, but flag it clearly: "Dry-run failed twice — needs a real interview, not a skim," not the old unqualified "needs interview" language.

## 6. This never replaces human review or authorizes auto-merge

A passed dry-run is real signal — stronger than lint alone — but it's still one LLM grading another LLM's natural-language instructions, not proof of correctness. Every PR from this path keeps a "Needs interview" section regardless of verdict; a pass changes its framing from "wasn't tested at all" to "passed N/N automated checks, still wants a human skim for intent-fit." It does not authorize skipping the human read, and passing this check never authorizes auto-merging the PR on its own — see `principles/core.md`'s "Decision authority" section: whether a brand-new skill is actually wanted is exactly the kind of call that stays with Michael.
