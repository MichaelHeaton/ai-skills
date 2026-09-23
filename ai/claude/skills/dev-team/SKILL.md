---
version: 1.12.0
principles_version: 1.0.0
last_updated: 2026-09-23
updated_by: claude
name: dev-team
description: Run a ticket through a lightweight multi-agent build pipeline — Architect plans and asks clarifying questions, Coder implements, Tester adversarially checks the diff, Docs updates stale documentation, and a conditional Manager gates on risk. Use when working a ticket end-to-end and you want plan approval before code gets written, or when you say "run this through dev-team", "spin up the dev team on this ticket", "architect this ticket", "build this with the team" — or open with plain ticket-start phrasing like "start #NNN", "let's work #NNN", "pick up #NNN", or "work on #NNN". Offer or invoke on that phrasing instead of defaulting to in-session coding — triggering only surfaces the Architect plan; Coder never runs until you approve it. Complements decision-council (which resolves opinions/tradeoffs, not builds) and reuses model-route for per-role model selection. Do NOT use for a quick one-line fix — the Architect step exists to catch ambiguity on real work, not to gate trivial changes.
compatibility: Requires ai/claude/agents/dev-team-coder.md, dev-team-tester.md, dev-team-manager.md, dev-team-docs.md (deployed via `make install-system`). dev-team-security.md is optional — only needed if Manager's on-demand security escalation (Step 5) is ever invoked.
---

# Dev Team

A 5-role pipeline for working tickets: Architect (this session) → Coder → Tester → Docs → conditional Manager. Built to avoid the token-burn failure mode of an earlier per-ticket agent design, where every invocation reloaded a full agent regardless of ticket size. Only Architect runs by default; Coder/Tester/Docs/Manager are real subagents in `ai/claude/agents/`, spawned via the Agent tool only after plan approval, each scoped to the plan and diff — never the full repo.

This design went through three rounds of `decision-council` review plus a backtest against 20 real merged PRs before landing on 5 roles. Rejected along the way: a Scout role, a Tester/Reviewer split, dedicated Security and SRE roles, and a shared cross-skill agent registry — all deferred as unearned scope until a concrete gap justified them. See the "Known limitations" section below for what the backtest actually found.

## Step 1 — Architect (this session, synchronous)

Read the ticket. Do NOT spawn any agents yet.

**Live-infra-ops pre-screen — check this first, before anything else below.** A state-migration or backend-cutover ticket can look like a bounded, plannable code change at plan time and unfold as an iterative verify-in-place ops session once Coder actually starts — the ops signal often doesn't fire until well into the build. Recognize it up front instead: `migrate-state`, `backend cutover`, `iterative CLI verification`, `live cluster state`, `multi-phase with no fixed diff` are the recognizable signals. If any apply, say so immediately and treat it as an extended direct-operations session — skip Coder/Tester/Docs/Manager entirely, the same outcome as step 7's research/docs case below. Don't let the Architect conversation draft a Coder plan before this signal is checked.

**New-skill pre-screen — check this second.** A ticket asking to create a new skill, subagent, hook, or MCP server (`type/new-skill` label, a title like "New skill idea: ..." or "skill idea: ...") is not generic code — it's a natural-language behavior spec with its own trigger-correctness and behavioral-correctness concerns that a bare Coder diff has no way to check. Hand off to `skill-create` _(global: ai-skills)_ instead of drafting a Coder plan: skip straight to its guided flow (or, with no live user present — an unattended/scheduled run — its [unattended dry-run](../skill-create/references/unattended-dry-run.md) procedure) for the actual authoring and testing. This is the same class of hand-off as step 7's research/docs case below, just recognized earlier because a `type/new-skill` ticket is identifiable from its label/title alone, before any file-scanning. Several past unattended drafts (ai-skills#847, #848, #849, #772, #799, #562) shipped through a bare Coder diff with testing skipped entirely and only a "needs interview" note — this pre-screen exists so that doesn't keep happening.

1. Scan the repo for the smallest useful context — the files the ticket actually touches, not the whole tree.
2. **Verify your own checkout is fresh, then check whether the ticket is already resolved.** Run `git fetch origin <default-branch>` and compare against local — fast-forward if clean — before scanning context or checking `git log`/`git blame` against the ticket's described files and behavior. Both checks need current `origin/main` state to be meaningful: a prior commit may have already fixed the ticket without referencing it, and a stale local checkout can make either judgment silently wrong — this mirrors Step 5's pre-flight check for Manager (same failure mode: a stale local `main` produces a false verdict), applied here before Architect drafts a plan instead of before Manager gates one. Catching this here is deterministic instead of relying on ad hoc judgment mid-plan. If already resolved, skip straight to closing the ticket with a citation to the fixing commit; there's no plan to draft or diff for Coder to produce.
3. **Check whether the fix location resolves to a different repo than the ticket is filed in** — via a symlink (a deployed skill path resolving to a different on-disk checkout) or general repo structure. Cross-reference git-ops's "Worktree path safety when editing" section rather than re-deriving the check. If the target repo differs, name it explicitly in the build plan below — Coder needs to know which repo it's actually working in before it spawns.
4. **Resolve ambiguity yourself first** — per `principles/core.md`'s "Decision authority" section, most plan ambiguity is an implementation-shape call (precedent from a sibling skill, `references/conventions.md`, or a logged decision settles it), not something that needs Michael. Decide it, state the decision and its one-line rationale directly in the plan below, and move on. Ask a clarifying question — up to 3, batched in one turn — only for the narrow remainder: a genuine call about priorities or goals that nothing in the repo signals either way. Don't ask a question precedent already answers, and don't proceed on a plan whose _unresolved_ ambiguity (the kind that does need Michael) was silently guessed instead of flagged.
5. Write a short build plan: files to touch, the approach, the **branch name** Coder should commit on, and the Coder specialty (`generic`, `terraform`, `db`, `ansible` — default `generic` unless the ticket clearly needs a specialist prompt swap). Naming the branch explicitly in the plan gives Step 2's verification something concrete to check against. If Step 3 above found a cross-repo fix location, the plan must name that target repo, not the ticket's filing repo.
6. **If the plan hinges on an external convention, standard, or spec claim** (e.g. which of two competing file-naming conventions a tool actually supports, how a third-party API is documented to behave), verify it via WebFetch/WebSearch before finalizing the plan — don't assert it from memory. Mirrors the same gate `skill-create` uses for claimed product schema/behavior.
7. **If the approved plan turns out to need no code changes** — pure research, ticket-creation, or documentation work — stop here by design, not by omission. Hand off explicitly instead of drafting the follow-on work ad hoc in this session: ticket creation goes through `issue-create`, documentation goes through `doc-coauthor`. Skip Coder/Tester/Docs/Manager entirely; there's no diff for them to act on.
8. Present the plan and **stop for explicit approval** before spawning anything. This is the approval gate — Coder/Tester/Docs/Manager never speculatively spin up.

## Step 2 — Coder (background subagent)

Once approved, spawn `dev-team-coder` via the Agent tool with: the approved plan, the ticket text, and the file list from step 1. Nothing else — no full-repo dump.

Route the model via `model-route`'s decision table before spawning (implementation-tier work is `sonnet` by default; only override if the plan itself flags unusually hard cross-cutting reasoning).

**Coder now proves failure before fixing it (adopted via `decision-council` review, 2026-09-13).** Before implementing, Coder reproduces the actual bug for a bug-fix ticket, or defines and fails the equivalent verification check for new-capability work (a health/readiness probe, an integration test against a new surface) — then confirms it passes after the fix. That check gets committed as a persisted, discoverable artifact (a test-suite addition, or a named diagnostic script when no test harness applies) instead of an ephemeral local run, so it keeps doing work later: running automatically going forward, or giving whoever triages a related production failure a known place to look. Full requirement lives in `dev-team-coder.md`. This isn't gated on ticket type — Coder applies it whenever a meaningful failure signal exists and states explicitly when it doesn't, rather than writing a trivial or tautological check to satisfy the letter of the requirement. Tester (Step 3) spot-checks that the evidence is real rather than re-deriving it.

**Before trusting Coder's "completed" report, verify actual repo state directly** — a task status of "completed" reflects the harness's task lifecycle, not necessarily that a commit landed. Coder has self-reported done while work was still uncommitted or a verification loop was still in progress. Run, in Coder's worktree:

```bash
git status --short
git log main..HEAD --oneline
```

Empty `git status --short` and at least one commit in the log is the actual completion signal, not the task status word. If either check fails, resume the same agent via `SendMessage` and ask it to finish and commit before proceeding.

**Hard cap on resume attempts.** If two resumes in a row still don't produce a clean `git status --short` and a real commit, stop treating this as an Architect-side verification loop — resuming a third time on the assumption "it just needs one more nudge" is how this becomes indefinite. Flag it as a Coder defect instead: report what's actually on disk to the user and ask how to proceed, rather than resuming again.

**When the ticket's fix repo differs from this Architect session's own repo** (per Step 1's cross-repo fix-location check), confirm Coder actually isolated into the _target_ repo's worktree — not the shared primary checkout — before trusting any diff:

```bash
git -C <target-repo-worktree-path> rev-parse --show-toplevel
git worktree list
```

Coder's own `EnterWorktree`/`ExitWorktree` tooling is supposed to handle this automatically, but it isn't fully reliable across repos — confirming here deterministically is cheap and catches a shared-checkout collision before it corrupts state, rather than by chance.

**Also confirm the branch name matches the plan.** Coder's isolation mode sometimes lands on the worktree's auto-generated scaffold branch name instead of the branch named in the approved plan:

```bash
git branch --show-current
```

If it doesn't match, rename before proceeding to Tester or push: `git branch -m <auto-generated-name> <planned-branch-name>`.

A background-agent task notification's `worktreeBranch` metadata field can lag this rename — it may still show the pre-rename auto-generated name even after the branch has been correctly renamed. Trust the direct `git branch --show-current` check above over the notification metadata; a mismatch there alone isn't a fresh problem and doesn't need re-verification.

**Clean up the stray scaffold branch the rename leaves behind.** Renaming with `git branch -m` above moves the _current_ branch pointer, but the worktree's original auto-generated name can still exist as a separate branch reference in the primary checkout afterward. Check for it:

```bash
git branch --list 'worktree-agent-*'
```

If one turns up, confirm it's safe before touching it — it must be a merged ancestor of `main`:

```bash
git merge-base --is-ancestor <worktree-agent-branch> main && echo safe-to-delete
```

If that prints `safe-to-delete`, remove it: `git branch -d <worktree-agent-branch>`. If it isn't an ancestor of `main`, leave it alone and flag it in your summary instead of deleting it silently — it may hold work that never made it into the renamed branch.

**Confirm the branch reached the remote before handing off to Tester or git-ops.** The local checks above confirm a commit landed, not that it's visible outside the worktree — an unpushed Coder branch has previously surfaced only later, as a `gh pr create` failure in git-ops. Check the final branch name (after any rename above):

```bash
git rev-parse --verify origin/<branch-name>
```

If that fails, push it yourself before proceeding: `git push -u origin <branch-name>`. Local commit _and_ a matching remote branch — not local commit alone — is Step 2's actual completion signal.

## Step 3 — Tester (background subagent, after Coder completes)

Spawn `dev-team-tester` with the diff Coder produced **and the ticket's stated acceptance criteria** (not just the diff — a "does the shipped value match the requirement" check needs the requirement text to check against). Tester's job is narrow: break what shipped, check the one pattern a backtest against real tickets confirmed generic review misses — privileged/binary downloads embedded in template-string or heredoc shell content where integrity verification is optional rather than enforced — and confirm every ticket-relevant changed value actually matches what the ACs say, not just that the code is structurally sound and plans/compiles cleanly. Tester reports findings; it does not fix anything.

**Before acting on Tester's output, confirm the report is actually complete.** A sub-agent can return a task status of "completed" while its final message is truncated mid-sentence or mid-list — that status field reflects the harness's task lifecycle, not whether Tester finished writing its verdict. If the report doesn't end with a clear ship/rework verdict statement, don't proceed on the partial read and don't re-spawn a fresh Tester from scratch. Instead, resume the same agent via the messaging tool used to continue sub-agents (`SendMessage`, addressed to that agent's id) and explicitly ask for a complete final report.

**Same hard cap as Step 2**: after two resumes without a complete verdict, stop resuming and flag it as a Tester defect to the user instead of treating it as an indefinite Architect-side verification loop.

**No automatic Reviewer step.** This pipeline has no `dev-team-reviewer` role, and code review does not auto-run after Tester clears. Tester and the `reviewer` subagent (`ai/claude/agents/reviewer.md`) answer different questions and are separate invocation decisions: Tester is adversarial diff testing scoped to what Coder just shipped — does it break, does it hide an unverified privileged download — and reports findings without judging the PR as a whole. Reviewer is broader hygiene against repo conventions, security, and correctness across the full diff. If you want that broader pass, spawn `reviewer` yourself once Tester clears; it never runs automatically.

## Step 4 — Docs (background subagent, deterministic trigger only)

**Coder never writes or updates documentation.** Its file list from Step 1 is implementation files only — that's enforced by `dev-team-coder.md` explicitly refusing doc edits. Detecting that docs are now stale, and writing the update, is entirely Docs' job. This step exists to make that detection concrete instead of assuming it happens by default.

You (Architect, this session) run this check against Coder's diff before deciding whether to spawn Docs — this is not Coder's or Docs' responsibility to notice on their own:

1. **Path glob**: does the diff touch `README*`, `docs/**`, or `CHANGELOG*`?
2. **Signature grep**: does the diff add, remove, or change any of — an exported/public function or class signature, a CLI flag or argument, a Terraform `variable`/`output`/`resource` schema, a public REST/API endpoint definition, or a config schema key?

If either check matches, spawn `dev-team-docs` with the diff. If neither matches, **skip this step entirely** — Docs is conditional on a mechanical check you just ran, not on judgment, and not on whether Coder happened to touch a doc file.

Docs runs the `humanizer` skill on any doc text it drafts so documentation stays factually accurate and doesn't read as AI-generated. Output is a **suggested diff, not an auto-commit** — a doc rewritten confidently-but-wrong is worse than a stale one; you review it before it lands.

## Step 5 — Manager (background subagent, conditional)

**Pre-flight — before spawning Manager, verify your own checkout is fresh.** `dev-team-manager` has no Bash tool (Read/Grep/Glob only), so it cannot fetch, pull, or otherwise confirm the files it's reading are current — it trusts whatever is on disk in this session's checkout. Run `git pull` (or otherwise confirm the local checkout matches the remote default branch) immediately before spawning Manager, every time, not just when a verdict looks wrong. A stale local `main` can make Manager report a false REWORK verdict claiming already-merged work isn't actually merged.

Spawn `dev-team-manager` only if either is true:

- **Tester flagged anything at any point during its review** — including a round-1 flag that got fixed and re-verified as SHIP before Tester's final report. A resolved flag still means real risk surfaced during this ticket, and Manager's process-verification job (below) is about whether the right tooling ran on that risk, not just about the final verdict text. Reading the final report alone and skipping Manager because it says SHIP is the wrong call.
- The diff crosses a size/risk threshold (touches `auth/`, `payments/`, IAM, or is large relative to the ticket's scope)

Otherwise skip Manager and go straight to your summary — most tickets don't need a fourth agent.

**For diffs that already cross the size/risk threshold above** (auth/credential handling, a persistent background service install, or similar) **spawn Manager in parallel with Tester instead of waiting for Tester to finish first.** A backtest found Manager catching real bugs — a data-loss race, an orphaned-file redaction gap — that Tester's first pass missed, and running strictly sequential meant those findings only surfaced after a full Tester pass, burning rework rounds against the pipeline's cap that earlier parallel spawning would have avoided. This only applies to diffs that already meet the risk threshold above — don't spawn Manager speculatively before Tester on ordinary tickets.

Manager does three things, not two:

1. **Judgment gate** on Tester's findings — pass/fail, not a diplomatic summary. If something's wrong, it says ship/rework/escalate, plainly.
2. **Process verification** — did the review tooling that should have run on this diff actually run (`iac-reviewer` for infra changes, `deep-review` for anything security/perf/architecture-sensitive, `adobe-security-suite` where applicable)? A backtest against 20 real merged PRs found the actual gaps weren't missing capability — they were existing tools never getting invoked before merge. Manager's job includes catching that.
3. **Security-control regression gate** — flags REWORK if the diff disables, weakens, or removes a security control (commented-out auth middleware, a widened firewall/network ACL, a disabled cert/TLS verification flag, a removed rate limit, or equivalent) with no linked tracking ticket naming an owner and revert-by date referenced in a commit message or the ticket/plan text. A linked ticket that already covers it clears the gate. See [principles/engineering-practices.md](../../../../principles/engineering-practices.md)'s "DevSecOps — shift security left" line for the rationale. This check only runs when Manager is already spawned under the conditions above — it is not a new spawn trigger. Manager also has a documented option, on an ambiguous case only, to reach for `dev-team-security` instead of deciding alone — see below.

**When Manager should reach for `dev-team-security` instead of relying on the mechanical gate alone.** The gate above is a cheap, always-on default, tuned for the common case: a clean signal-list match plus a ticket-link lookup is enough to decide most of the time, and that doesn't change. Escalate to `dev-team-security` only for the harder minority the gate can't resolve by pattern-matching alone — a control weakening that's clearly security-relevant but doesn't cleanly match the signal list, a linked ticket that names an owner and date but whose actual scope doesn't obviously cover the risk in front of you, or any case where clearing or failing the gate would require reasoning about exploitability and blast radius rather than list-matching. Manager has no `Agent` tool, so it cannot spawn `dev-team-security` itself — it names the finding and requests the escalation in its report, and you (Architect) spawn `dev-team-security` with the diff, the ticket/plan text, and Manager's finding, the same way you already handle any other Manager escalation. This is not a routine second opinion on every REWORK the mechanical gate already produces cleanly, and it is not a step that runs on every ticket — most tickets clear the gate without it.

If Manager escalates, it reports back to you and to the Architect step (this session) — not a silent loop. **Hard cap**: after 2 rounds of flag → replan → recode, stop and escalate to the user regardless of Manager's verdict.

**Rework fallback — `dev-team-coder`'s isolation mode always creates a fresh worktree; there is no parameter to target an existing one.** This applies whenever a rework round needs to land in the _same_ worktree Coder already committed to in round 1, regardless of which role triggered the rework — a Manager rework verdict, or a Tester-only REWORK round that gets fixed and re-verified before Manager ever spawns (e.g. fixing a collision Tester flagged in a shared module). In either case, do not re-spawn Coder — its `EnterWorktree`/`ExitWorktree` calls will create a second, unrelated worktree rather than reusing the first. Instead, apply the fix directly in the Architect session (this session), inside the existing worktree path, then re-run Tester against the updated diff. If a future Coder isolation mode adds support for targeting an existing worktree, prefer that over this fallback.

## Step 6 — Hand off to git-ops for the PR

Once Manager clears (or Manager was skipped and Tester found nothing), open the PR through the `git-ops` skill as normal — do not call `gh pr create` directly. This matters specifically because `git-ops` runs a mandatory `agent-md-sync` check before every PR: it diffs the branch against component directories (Ansible roles, Terraform modules, Helm charts, README-bearing dirs) in whatever repo Coder just touched, and flags any component whose `AGENT.md` is stale or missing.

No role in this pipeline owns AGENT.md staleness directly — not Coder, not Docs, not Manager. It's `git-ops`'s job, enforced at PR time, on every PR regardless of which skill produced the diff. Don't duplicate that check into Manager; just don't skip the `git-ops` handoff to get there.

After the `git-ops` handoff, verify a PR actually exists for the branch before treating the ticket as done or handed off: run `gh pr list --head <branch> --state all --json number,state`. A ticket can be fully committed and pushed with no PR ever opened — none of Coder/Tester/Manager/git-ops's own steps catch that on their own, so this check is the deterministic backstop. If the result is empty, don't silently move on to the next ticket — either retry the `git-ops` handoff or surface the gap explicitly (see Batch mode below for what to do when the session ends before this check can run).

## Batch mode

When working through several tickets in one session, this opt-in mode cuts down on interruptions without skipping any real gate:

- **Batch plan approval** — present 2-4 ticket plans together in one turn instead of one at a time, then get a single approval covering all of them before spawning anything for any of them.
- **Self-poll for PR merge state** — after a PR is opened, check `gh pr view <n> --json state,mergedAt` yourself on a reasonable cadence instead of waiting for the user to say "merged." Still never merge a PR yourself; only poll for state.
- **Mandatory direct diff verification per ticket** — before moving a ticket to Tester or trusting Coder's report, read the actual diff yourself (`git diff`, or the changed files directly) rather than only the Coder's self-report — this is the same discipline Step 2's completion check above requires, applied per-ticket across the whole batch, not just once.

- **Flag interrupted PR verification explicitly** — if the Architect session ends (interruption, context limit, or batch mode advancing to the next ticket) before Step 6's PR-existence check completes for a given ticket, that ticket must be flagged explicitly as "diff approved, PR pending" in the batch summary — never silently reported as done, and never silently dropped.

Batch mode changes the interaction cadence, not the pipeline's gates — every step above still runs for every ticket.

## Known limitations (carried from design review, not solved by this pipeline)

- **SCP/policy enforcement invisible at plan time** — infra changes that fail only at `apply` time due to AWS Service Control Policies won't be caught by any review step here. No agent fixes this; it needs an apply-time check or a maintained allowlist, out of scope for this skill.
- **`adobe-security-suite` coverage is account/environment-provisioned**, not a local file — don't assume its coverage exists outside an Adobe-provisioned Claude Code session.
- **Coder specialization is a prompt parameter, not a separate role** — `terraform`/`db`/`ansible` swap the system prompt Coder receives; they are not distinct agent files. Only promote a specialty to its own file once three real specialties are in production use.
- **Copying from a reference implementation can inherit a wrong assumption about the reference's own defaults.** A build modeled closely on an existing component can silently ship a config value that matches the reference's checked-in file default while missing that the reference's actual production behavior comes from an override elsewhere (a workspace variable, an environment-level default, etc.) — the copy looks structurally identical to the reference but is functionally different from what it was modeled on. Tester's AC-conformance check (Step 3) catches this only when the divergent value is also an explicit ticket AC; a divergence with no corresponding AC line can still slip through. No role currently verifies a reference component's _actual_ runtime defaults independent of its file contents.
- **`dev-team-security` is on-demand, not a revival of the rejected always-on Security role.** The design history above rejected a standing Security role twice — a full decision-council review plus a 20-PR backtest found no concrete gap that justified paying for it on every ticket. `dev-team-security` (added for real security-stance reasoning Manager's mechanical gate can't produce — see Step 5) is scoped narrowly to Manager's optional escalation on an ambiguous finding; it never runs by default and is not a new always-on pipeline step. Don't broaden its invocation beyond that escalation path without running the same decision-council review this pipeline's other role additions went through.

## Model routing

Call `model-route` when spawning each subagent rather than trusting a hardcoded tier — the frontmatter `model` field in each `ai/claude/agents/dev-team-*.md` file is a sensible default, not a mandate. Override at spawn time when the ticket's actual complexity warrants it.

## Token verification

Log tokens per role per ticket. This pipeline replaces a system that got replaced _because_ it burned tokens — if this one isn't measured, you can't tell if it actually fixed that.
