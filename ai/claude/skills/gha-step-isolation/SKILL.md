---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-12
updated_by: claude
name: gha-step-isolation
description: Diagnose and fix the GitHub Actions gotcha where a step writes to GITHUB_PATH or GITHUB_ENV and then immediately tries to use that new PATH entry or env var in the *same* step — which fails, because both only take effect starting with the *next* step. Trigger when a step installs a tool into a custom dir (e.g. `~/.local/bin`), appends it to `$GITHUB_PATH`, then calls that tool later in the same step and gets "command not found"; when debugging "works locally, fails in Actions" for a freshly-installed CLI; when a step writes `$GITHUB_ENV` and reads that var right after in the same `run:` block and gets empty; or when reviewing/writing a workflow step that installs and uses a tool. Covers the fixes — export PATH inline in the same step instead of relying on GITHUB_PATH, or split install and first-use into two steps — plus a runner tool-assert (`command -v`) to fail fast instead of a confusing downstream "command not found".
compatibility: Cloud-compatible — no local-machine-only paths or tooling. Applies to any GitHub Actions workflow YAML.
---

# GHA Step Isolation

`GITHUB_PATH` and `GITHUB_ENV` writes in a GitHub Actions step never apply to that same step — only to steps that run *after* it. A step that installs a tool, appends its directory to `$GITHUB_PATH`, and then calls that tool later in the same `run:` block will fail with "command not found," because the runner only re-reads `$GITHUB_PATH`/`$GITHUB_ENV` between steps, not mid-step. This is easy to miss because the exact same script works fine locally, where `PATH` is already set in the shell.

## 1. Recognize the failure signature

- A step installs a binary into a custom location (commonly `~/.local/bin`, `~/bin`, or a vendored dir not already on `PATH`).
- The same step appends that directory to `$GITHUB_PATH` (e.g. `echo "$HOME/.local/bin" >> "$GITHUB_PATH"`).
- The same step then invokes the newly-installed binary directly (e.g. `kubectl version`) and gets `command not found` or `kubectl: command not found`, even though the install step reported success.
- The identical pattern with `$GITHUB_ENV` shows up as a var read as empty (`echo "$FOO"` prints nothing) immediately after a `echo "FOO=bar" >> "$GITHUB_ENV"` in the same step.

If the install and the failing use are in the same `run:` block or the same `steps:` entry, this is step-isolation — not a broken installer, wrong path, or missing package.

## 2. Apply the canonical fix

Two fixes both work; pick based on whether the tool is needed again in later steps.

**Fix A — export PATH inline, skip GITHUB_PATH entirely.** Use this when the tool is only needed within the current step:

```yaml
- name: Install and use kubectl
  run: |
    curl -sSL -o "$HOME/.local/bin/kubectl" https://example.invalid/kubectl
    chmod +x "$HOME/.local/bin/kubectl"
    export PATH="$HOME/.local/bin:$PATH"
    kubectl version --client
```

`export PATH=...` takes effect immediately in the current shell process, unlike `$GITHUB_PATH`, which is only read by the runner when it starts the *next* step's shell.

**Fix B — split install and first use into separate steps.** Use this when later steps (or later jobs sharing the same runner) also need the tool on `PATH` without re-exporting it each time:

```yaml
- name: Install kubectl
  run: |
    curl -sSL -o "$HOME/.local/bin/kubectl" https://example.invalid/kubectl
    chmod +x "$HOME/.local/bin/kubectl"
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"

- name: Use kubectl
  run: kubectl version --client
```

Here `$GITHUB_PATH` is the right mechanism — it just needs a step boundary between the write and the first read. The same split applies to `$GITHUB_ENV`: write in one step, read starting in the next.

**Do not** try to work around this by re-sourcing a profile script or `source ~/.bashrc` mid-step — GitHub Actions runners don't source shell rc files between commands, so that doesn't fix isolation and adds a fragile dependency on shell startup behavior.

## 3. Add a runner tool-assert to fail fast

Even with the fix applied, add a cheap assertion right after install (or at the top of the step that first depends on the tool) so a regression fails with a clear message instead of a confusing "command not found" several lines into unrelated output:

```yaml
- name: Assert kubectl is on PATH
  run: |
    command -v kubectl || { echo "::error::kubectl not found on PATH after install"; exit 1; }
```

`command -v` (preferred over `which` — it's a shell builtin, no external dependency) exits non-zero immediately if the tool isn't resolvable, and the `::error::` annotation surfaces the failure in the GitHub Actions UI instead of burying it in a raw shell trace. Place this assert as its own step (or as the first line of the step that depends on the tool) so the failure points at the actual cause — a missing `PATH` entry — rather than at whatever command happens to run next.

## 4. Quick checklist when reviewing a workflow step

- Does this step write to `$GITHUB_PATH` or `$GITHUB_ENV` and then read the result in the same step? → apply Fix A or split per Fix B.
- Does a later step assume a tool installed earlier is on `PATH`? → confirm the install step used `$GITHUB_PATH` (not just a local `export`, which doesn't persist across steps) and consider a tool-assert at the top of the consuming step.
- Is the fix itself untested? → a runner tool-assert (Step 3) turns a silent latent break into a fast, clear failure the next time this changes.
