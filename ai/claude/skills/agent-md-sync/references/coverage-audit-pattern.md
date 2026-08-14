---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Coverage audit pattern

Any skill that pattern-matches repo structure to build a list (components, tech-stack manifests, config files) is only as good as its rules — and rules trained on known layouts have blind spots on layouts nobody anticipated. `agent-md-sync`'s `check-coverage.sh` was built to catch its own `discover-components.sh`'s blind spots; the pattern generalizes to any skill in the same shape.

## The pattern

1. **A rule-based detector** produces a list of "things found" using pattern-matching rules (e.g. `discover-components.sh`'s category rules: Ansible roles under `roles/`, Terraform modules with `main.tf`, Helm charts with `Chart.yaml`).
2. **An independent, marker-file-only scan** searches the same repo for the same underlying signal (the marker files each rule actually keys off) without going through the rule-based detector's category logic — a dumb `find` for each marker pattern, not a re-implementation of the rules.
3. **Diff the two.** Anything the independent scan found that the rule-based detector's list doesn't contain is a blind spot: `MISSED:<category>:<path>`.
4. **A `MISSED` line is evidence a rule needs widening — not a reason to widen it preemptively.** Don't add speculative categories the independent scan hasn't actually surfaced.

## Why two passes instead of one better one

A single smarter detector still has rules, and rules still have blind spots — the point of running an independent, deliberately dumber scan alongside it is that the two are unlikely to share the same blind spot. The marker-file scan doesn't need to *understand* what a component is; it just needs to find the same files the rule-based detector's rules were written to key off, plus a few more.

## Applying this pattern to a new detector

To apply this to a skill that isn't `agent-md-sync`:

1. Identify the detector's actual signal — the specific file(s)/pattern(s) each rule keys off, not the rule's higher-level category name.
2. Write a marker-only scan for those same signals, independent of the detector's own code path.
3. Diff detector output against scan output; report `MISSED:<category>:<item>`.
4. Keep the check separate from the detector itself — it exists to catch the detector's blind spots, so it shouldn't share the same code (and therefore the same blind spots).

**Applied to `repo-ai-init`**: `discover.sh`'s "TECH STACK" section checks a fixed list of manifest filenames (`package.json`, `go.mod`, `Cargo.toml`, etc.) — the same shape of rule-based list as `discover-components.sh`'s categories, just for build manifests instead of component directories. `repo-ai-init/scripts/check-tech-stack-coverage.sh` applies this pattern: an independent scan for a broader set of known manifest patterns, reporting any the fixed list would miss as `MISSED:tech-stack:<file>`.
