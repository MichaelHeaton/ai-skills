---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: brew-sync
description: Audit installed Homebrew formulae/casks against what's tracked in a workstation config repo (e.g. group_vars/all.yml), surfacing recently installed packages first so ad hoc installs don't accumulate untracked indefinitely. Use periodically, or when asked "what's installed but not tracked", "sync my Homebrew packages", "check for untracked brew installs", or "what did I install outside the playbook".
compatibility: Requires Homebrew (macOS/Linux) and a config repo with a tracked package list.
---

# Brew Sync

Packages installed ad hoc (`brew install X` to unblock something right now) accumulate untracked drift from the config-managed list. This audits the gap and surfaces it in priority order — recent installs first, since those are the ones most likely to still be intentional and worth adding, versus old untracked cruft nobody remembers installing.

## 1. List installed packages

```bash
brew list --formula
brew list --cask
```

## 2. Diff against the tracked list

Compare against the config repo's tracked package list (`group_vars/all.yml` or the repo's equivalent — check the actual file, don't assume the exact path). Produce two lists: installed-but-untracked, and tracked-but-not-installed (the config says it should be there and it isn't — a different kind of drift, worth surfacing too).

## 3. Surface by recency

For untracked packages, sort by install time so the newest (most likely still relevant) appear first:

```bash
for pkg in $(brew list --formula); do
  receipt="$(brew --cellar)/$pkg"/*/INSTALL_RECEIPT.json
  ts=$(stat -f "%m" $receipt 2>/dev/null | sort -rn | head -1)
  echo "$ts $pkg"
done | sort -rn
```

(On Linux, use `stat -c "%Y"` instead of `stat -f "%m"`.)

## 4. Filter dependency noise

Most untracked packages aren't things anyone `brew install`ed directly — they're dependencies pulled in automatically. Filter these out before presenting the list:

```bash
brew leaves    # top-level installs only, excludes auto-installed dependencies
```

Cross-reference the untracked list against `brew leaves` — anything not in `brew leaves` is a dependency, not a package someone chose to install, and doesn't need tracking on its own.

## 5. Report

```
Untracked (top-level, sorted by recency):
- fzf (installed 3 days ago)
- ripgrep (installed 19 days ago)

Tracked but not installed:
- shellcheck
```

Let the user decide what to add to the config repo and what to leave as a one-off — don't auto-edit the tracked list.
