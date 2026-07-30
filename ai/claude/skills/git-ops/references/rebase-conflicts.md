---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-07-30
updated_by: claude
---

# Multi-commit same-file rebase conflicts

When a branch has multiple commits that all touch the same file **and** the default branch has also changed that file, `git rebase main` conflicts at every replayed commit — not just once. Each step re-introduces a conflict against the already-resolved state.

**Detect it early** before starting a rebase:

```bash
# How many commits on this branch touch the file?
git log main..HEAD --oneline -- <file>

# Has main also changed it since the branch diverged?
git diff main...HEAD -- <file>
```

If both return non-empty output, do **not** rebase. Instead:

1. **Capture the net diff** — what does this branch add that isn't in main?

   ```bash
   git diff main...HEAD -- <file> > /tmp/net-changes.patch
   ```

2. **Abort any in-progress rebase**

   ```bash
   git rebase --abort
   ```

3. **Create a fresh branch from the updated default branch**

   ```bash
   git checkout main && git pull
   git checkout -b <new-branch-name>
   ```

4. **Apply the net-new changes in a single commit** — manually apply from the patch or re-author the content from scratch if cleaner.

5. **Push the new branch and open a new PR**; close the old branch with a note referencing the replacement.

**Why not squash the original branch and rebase that?** Squash still replays the squashed commit against main's version of the file — one conflict instead of five, but the resolution is the same work. The fresh-branch approach is equivalent and sidesteps git's rebase state machine entirely.
