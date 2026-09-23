#!/usr/bin/env bash
# Regression test for prune-branches.sh's safety logic (ai-skills#871).
#
# Covers the specific failure modes a dev-team Tester pass found in this
# script's history: `git cherry` per-commit patch-id matching (1) missed
# multi-commit squash merges entirely and (2) could be fooled by a
# patch-id coincidence into force-deleting content not actually on main.
# The fix replaced that check with `git merge-tree --write-tree`. This test
# builds real bare+clone git fixtures for each case and asserts the script's
# actual output/exit behavior, so a future change to the safety logic has
# something concrete to break instead of silently regressing.
#
# Usage: prune-branches.test.sh
# Exits 0 if all cases pass, 1 with a diagnostic on the first failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/prune-branches.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mk_repo() {
  local name="$1"
  git init -q --bare "$WORK/$name-origin"
  git clone -q "$WORK/$name-origin" "$WORK/$name-work"
  git -C "$WORK/$name-work" config user.email t@t.com
  git -C "$WORK/$name-work" config user.name t
}

# --- Case 1: multi-commit squash merge must be recognized as safe ---
mk_repo case1
REPO="$WORK/case1-work"
git -C "$REPO" checkout -qb main
echo l1 > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init
git -C "$REPO" push -q -u origin main

git -C "$REPO" checkout -qb feat-squash
echo a > "$REPO/a.txt"
git -C "$REPO" add a.txt
git -C "$REPO" commit -qm "add a"
echo b > "$REPO/b.txt"
git -C "$REPO" add b.txt
git -C "$REPO" commit -qm "add b"
git -C "$REPO" push -q -u origin feat-squash

git -C "$REPO" checkout -q main
git -C "$REPO" merge --squash feat-squash -q
git -C "$REPO" commit -qm "squash merge feat-squash"
git -C "$REPO" push -q origin main
git -C "$REPO" push -q origin --delete feat-squash
git -C "$REPO" fetch -q --prune origin

OUT=$(bash "$TARGET" "$REPO" --yes 2>&1) || fail "case1: script exited nonzero: $OUT"
grep -q "feat-squash" <<<"$OUT" || fail "case1: feat-squash not mentioned in output: $OUT"
grep -q "NOT SAFE.*feat-squash" <<<"$OUT" && fail "case1: multi-commit squash merge incorrectly flagged NOT SAFE: $OUT"
git -C "$REPO" show-ref --verify --quiet refs/heads/feat-squash && fail "case1: feat-squash was not deleted"
echo "PASS: case1 (multi-commit squash merge deleted as safe)"

# --- Case 2: a real unmerged branch must never be deleted ---
mk_repo case2
REPO="$WORK/case2-work"
git -C "$REPO" checkout -qb main
echo l1 > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init
git -C "$REPO" push -q -u origin main

git -C "$REPO" checkout -qb feat-unmerged
echo unique > "$REPO/c.txt"
git -C "$REPO" add c.txt
git -C "$REPO" commit -qm "genuinely unmerged"
git -C "$REPO" push -q -u origin feat-unmerged
git -C "$REPO" push -q origin --delete feat-unmerged
git -C "$REPO" checkout -q main
git -C "$REPO" fetch -q --prune origin

OUT=$(bash "$TARGET" "$REPO" --yes 2>&1) || true
grep -q "NOT SAFE.*feat-unmerged" <<<"$OUT" || fail "case2: genuinely unmerged branch not flagged NOT SAFE: $OUT"
git -C "$REPO" show-ref --verify --quiet refs/heads/feat-unmerged || fail "case2: feat-unmerged was deleted (must never happen)"
echo "PASS: case2 (genuinely unmerged branch preserved)"

# --- Case 3: patch-id coincidence (revert then identical re-add elsewhere)
#     must NOT produce a false "safe" verdict ---
mk_repo case3
REPO="$WORK/case3-work"
git -C "$REPO" checkout -qb main
echo l1 > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init
git -C "$REPO" push -q -u origin main

git -C "$REPO" checkout -qb feat-collision
echo collision >> "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm "adds collision content"
git -C "$REPO" push -q -u origin feat-collision

git -C "$REPO" checkout -q main
echo collision >> "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm "add collision content"
git -C "$REPO" revert --no-edit HEAD >/dev/null
git -C "$REPO" push -q origin main
git -C "$REPO" push -q origin --delete feat-collision
git -C "$REPO" fetch -q --prune origin

OUT=$(bash "$TARGET" "$REPO" --yes 2>&1) || true
grep -q "NOT SAFE.*feat-collision" <<<"$OUT" || fail "case3: patch-id-coincidence branch incorrectly treated as safe: $OUT"
git -C "$REPO" show-ref --verify --quiet refs/heads/feat-collision || fail "case3: feat-collision was force-deleted despite content not actually on main"
echo "PASS: case3 (patch-id coincidence correctly rejected)"

# --- Case 4: repo with master (not main) and no origin/HEAD must not crash ---
mk_repo case4
REPO="$WORK/case4-work"
git -C "$REPO" checkout -qb master
echo l1 > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init
git -C "$REPO" push -q -u origin master

set +e
OUT=$(bash "$TARGET" "$REPO" 2>&1 </dev/null)
STATUS=$?
set -e
[[ "$STATUS" -eq 0 ]] || fail "case4: script crashed on master-only/no-origin-HEAD repo (exit $STATUS): $OUT"
grep -q "Safe to delete (0)" <<<"$OUT" || fail "case4: expected clean empty-candidates output, got: $OUT"
echo "PASS: case4 (master-only repo with no origin/HEAD handled cleanly)"

# --- Case 5: a failed deletion (locked ref) must propagate a nonzero exit ---
mk_repo case5
REPO="$WORK/case5-work"
git -C "$REPO" checkout -qb main
echo l1 > "$REPO/f.txt"
git -C "$REPO" add f.txt
git -C "$REPO" commit -qm init
git -C "$REPO" push -q -u origin main

git -C "$REPO" checkout -qb feat-locked
echo x > "$REPO/x.txt"
git -C "$REPO" add x.txt
git -C "$REPO" commit -qm "will be merged"
git -C "$REPO" checkout -q main
git -C "$REPO" merge -q feat-locked
git -C "$REPO" push -q -u origin feat-locked
git -C "$REPO" push -q origin main
git -C "$REPO" push -q origin --delete feat-locked
git -C "$REPO" fetch -q --prune origin

# Simulate a concurrent git process holding the ref lock.
touch "$REPO/.git/refs/heads/feat-locked.lock"

set +e
OUT=$(bash "$TARGET" "$REPO" --yes 2>&1)
STATUS=$?
set -e
rm -f "$REPO/.git/refs/heads/feat-locked.lock"

[[ "$STATUS" -ne 0 ]] || fail "case5: script exited 0 despite a real deletion failure (locked ref): $OUT"
echo "PASS: case5 (deletion failure propagates nonzero exit)"

echo "All prune-branches.sh tests passed."
