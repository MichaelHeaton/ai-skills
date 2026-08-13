---
version: 1.2.1
principles_version: 1.0.0
last_updated: 2026-08-13
updated_by: claude
name: agent-md-sync
description: Generate and maintain component-level AGENTS.md files — either for a single named component (skips full-repo discovery, jumps straight to reading and drafting) or across an entire repo (scan mode). Keeps AI context co-located with code so agents can navigate specific roles, modules, or components without scanning the whole repo. Detects and respects a repo's existing AGENT.md/AGENTS.md convention rather than assuming one. Called automatically by git-ops before PR creation to catch stale or missing component AGENT.md/AGENTS.md files. Trigger on: "generate agent md for this role", "create component AGENTS.md", "scan repo for components", "check which AGENT.md files are stale", "document this module", "add AI context to this role", or when git-ops invokes it before PR creation.
compatibility: Requires git. Scan mode requires a repo with recognizable component structure (Ansible roles, Terraform modules, Helm charts, or README-bearing subdirectories).
---

Component-level AGENT.md/AGENTS.md files give AI agents focused context without scanning the whole repo. They live alongside the component — `roles/nginx/AGENTS.md`, `modules/vpc/AGENTS.md` — and link back to the root AGENTS.md (or AGENT.md, if that's the repo's existing convention) for repo-wide conventions.

This skill operates in two modes:

- **Scan mode** — discover all components in a repo and generate missing AGENT.md/AGENTS.md files. When the user names a specific component at invocation ("create AGENT.md for `roles/nginx`"), this is a single-component request through scan mode, not a separate mode — skip Step 1's discovery script (which scans the whole repo) and go straight to Step 3, since the target is already known.
- **Check mode** — given a branch diff, identify which component AGENT.md/AGENTS.md files are stale or missing, warn the user, and offer to update them before PR creation

The scripts in this skill resolve which filename convention a repo already uses (checking for `AGENTS.md` first, then `AGENT.md`, defaulting to `AGENTS.md` if neither exists) rather than assuming the singular form.

> Read `references/component-agent-md-spec.md` before writing any component AGENT.md/AGENTS.md file.

---

## Scan mode

Use scan mode when:

- Setting up a repo for the first time (called by `repo-ai-init` after the root AGENTS.md is written)
- Auditing a repo where components have been added since the last scan
- User explicitly asks to scan or document all components

### Step 1 — Discover components

**Skip this step if the user already named a specific component** (e.g. "create AGENT.md for `roles/nginx`") — go straight to Step 3 with that path. Discovery scans the whole repo; that's overhead when the target is already known.

Run the discovery script from the repo root:

```bash
bash <path-to-skill>/scripts/discover-components.sh [repo-path]
```

The script identifies:

- **Ansible roles**: directories under `roles/` containing `tasks/main.yml` or `tasks/main.yaml`
- **Ansible playbooks directory**: `playbooks/` if present
- **Terraform modules**: directories under `modules/` containing `main.tf`
- **Terraform roots**: directories 2+ levels deep (outside `modules/`) containing `main.tf` — catches per-environment deployments like `networking_infra/prod_va6/`
- **Helm charts**: directories under `charts/` containing `Chart.yaml`
- **Generic components**: first-level subdirectories containing a `README.md` not already caught above

Output is one line per component: `TYPE:PATH:HAS_AGENT_MD`

### Step 2 — Prioritize gaps

After reading discovery output, focus on components that:

1. Have no AGENT.md/AGENTS.md (completely blind to AI — highest priority)
2. Are large or frequently modified (check `git log --oneline -- <path>` depth)
3. Have complex inputs, non-obvious behavior, or known gotchas

If there are many gaps, ask the user which to document now vs. defer. Don't generate everything at once without confirmation.

### Step 3 — Read the component

**First, check whether the target file already exists** — `<component-path>/AGENTS.md` or `<component-path>/AGENT.md` — before reading anything else. This applies every time, including the single-component path that skips Step 1's discovery (discovery is what normally surfaces `HAS_AGENT_MD=true`; skipping it does not exempt this check). If it exists, read it in full. The draft in Step 4 must then be a merge/update against that existing content, not a fresh replacement — preserve accurate existing material (tables, gotchas, runbook links) and only change what's stale or missing. Writing a thinner draft over a substantial existing file silently destroys real content.

For each component to document, also read its key files before drafting anything:

**Ansible role** — read `tasks/main.yml`, `defaults/main.yml`, `vars/main.yml`, `README.md` (if present). Understand: what the role configures, required vs. optional variables, idempotency behavior, what it deploys.

**Terraform module** — read `main.tf`, `variables.tf`, `outputs.tf`. Understand: what infrastructure it provisions, required vs. optional inputs, what it outputs, provider requirements.

**Helm chart** — read `Chart.yaml`, `values.yaml`, 2–3 key templates. Understand: what it deploys, configurable values, chart dependencies.

**Generic component** — read `README.md` and 2–3 key source files. Understand: purpose, interfaces, dependencies.

Also check the root AGENTS.md (or AGENT.md, if that's the repo's existing convention) to confirm what's already documented repo-wide — do not repeat it in the component file.

### Step 4 — Draft and confirm

Draft the component AGENTS.md using the spec in `references/component-agent-md-spec.md`. Show the draft to the user before writing. Apply feedback, then write to `<component-path>/AGENTS.md` (or `<component-path>/AGENT.md`, if that's the repo's existing convention).

Report the full list of components documented and any that were skipped.

---

## Check mode (invoked by git-ops before PR creation)

Check mode runs automatically as part of the git-ops PR creation flow. It requires no arguments — it operates on the current repo and branch.

### Step 1 — Get the diff

```bash
bash <path-to-skill>/scripts/check-pr-diff.sh [base-branch]
```

Default base branch is `main` (falls back to `master`). The script walks all files changed in this branch and reports, per component directory:

- `STALE:<path>` — directory has an AGENTS.md (or AGENT.md), code files changed, but it was not modified in this branch
- `MISSING:<path>` — directory matches a known component pattern but has no AGENTS.md/AGENT.md at all
- `OK:<path>` — AGENTS.md (or AGENT.md) was updated alongside its code (no action needed)

The script respects `.agent-md-ignore` in the repo root — paths listed there are silently skipped.

### Step 2 — Warn and prompt

If any `STALE` or `MISSING` findings exist, pause before `gh pr create` and present:

> **AGENT.md/AGENTS.md check — documentation may be out of date**
>
> These components were modified in this branch but their AGENTS.md files were not updated:
>
> - `roles/nginx/` — AGENTS.md exists but not updated **(stale)**
> - `modules/vpc/` — no AGENTS.md exists **(missing)**
>
> **What would you like to do?**
>
> - **Update/create now** — generate AGENTS.md content and include it in this PR
> - **Skip for now** — continue with PR creation; note the gap in the PR description
> - **This component doesn't warrant an AGENTS.md** — skip and suppress future warnings (adds to `.agent-md-ignore`)

If no findings exist (all `OK` or no components touched), proceed silently — no prompt needed.

### Step 3 — Handle the response

**"Update/create now"**: Use the read-and-draft flow from scan mode Step 3. Show draft, get confirmation, write the file, stage it alongside the existing changes. The AGENTS.md update becomes part of the same PR as the code change.

**"Skip for now"**: Add a `## Documentation` section to the PR description:

```
## Documentation
⚠️ Component AGENTS.md files not updated in this PR: `roles/nginx/`, `modules/vpc/`.
Update before or after merging if context changed significantly.
```

**"This component doesn't warrant an AGENTS.md"**: Append the path to `.agent-md-ignore` (create the file if it doesn't exist). Stage the file so it goes into the PR.

### Step 4 — Return to git-ops

After resolving all findings, return control to git-ops and proceed with PR creation.

---

## Integration with repo-ai-init

After `repo-ai-init` writes the root AGENTS.md (or AGENT.md, if that's the repo's existing convention) and CLAUDE.md, offer to continue with scan mode:

> "Root AGENTS.md written. Would you like to also generate component-level AGENTS.md files for the roles/modules in this repo?"

This is optional — offer it, don't force it. If the repo has many components, the user may prefer to generate them incrementally as they work in each one.

---

## Maintenance note

Component AGENTS.md files should evolve with their components. The check mode enforces this at PR time. The best time to update a component AGENTS.md (or AGENT.md, if that's the repo's existing convention) is immediately after an AI gets something wrong in that component — that's a gap, and a one-sentence addition to the Gotchas section closes it permanently.

---

## Auditing discover-components.sh itself

`discover-components.sh`'s category rules (ansible roles under `roles/`, terraform modules under `modules/`, first-level README dirs, etc.) are pattern-matched against known layouts — a new repo can have a layout none of them anticipate. Before trusting scan-mode output on an unfamiliar repo, or after changing detection rules, run:

```bash
bash <path-to-skill>/scripts/check-coverage.sh <repo-path> [repo-path...]
```

It independently scans the same repo(s) for known marker files (`tasks/main.yml`, `main.tf`, `Chart.yaml`, first-level `README.md`) at any depth and reports any directory `discover-components.sh` didn't pick up, as `MISSED:<type>:<path>`. Takes multiple repo paths in one call, so a set of repos in a workspace can be checked in one pass. A `MISSED` line is evidence a detection rule needs widening — not a reason to widen it preemptively.
