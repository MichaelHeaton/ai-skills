#!/usr/bin/env python3
"""
parse-tf-plan.py — tally and verify `terraform plan -json` / `apply -json` output.

Reads streamed JSONL (one JSON object per line, each with a "type" field) from
stdin or from a file path given as the first argument. Stdlib only — no pip
install required.

Usage:
    terraform plan -json | python3 parse-tf-plan.py
    python3 parse-tf-plan.py plan.jsonl
    python3 parse-tf-plan.py plan.jsonl expected-shape.json

Expected-shape file (optional, second argument) — a small JSON document:
    {
      "resource_counts": {"aws_instance": 3},
      "must_include": ["aws_vpc.main"],
      "must_exclude": ["aws_nat_gateway.legacy"]
    }

Exit status:
    0 — tally matches change_summary and (if given) the expected shape
    1 — a mismatch was found (usable as a gate, not just informational)
    2 — usage / input error (bad args, unreadable/empty/unparseable input,
        malformed expected-shape file)
"""

import json
import sys
from collections import Counter


def read_lines(path):
    if path:
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.readlines()
        except OSError as exc:
            print(f"error: could not read {path}: {exc}", file=sys.stderr)
            sys.exit(2)
    return sys.stdin.readlines()


def normalize_actions(action_field):
    """Terraform JSON logs represent an action as either a single string
    ("create", "update", "delete", "replace", "no-op", "read", "import") or,
    in some schema variants, a list of primitive actions (e.g. ["create",
    "delete"] for a create-before-destroy replace). Normalize to a list of
    strings."""
    if action_field is None:
        return []
    if isinstance(action_field, str):
        return [action_field]
    if isinstance(action_field, list):
        return [a for a in action_field if isinstance(a, str)]
    return []


def classify_change_line(actions):
    """Map a set of raw terraform actions to the add/change/remove/import
    buckets used in Terraform's own "Plan: N to add, M to change, K to
    destroy" summary. A replace is reported as one add + one destroy.
    Returns None for no-op or truly unrecognized action sets."""
    actions = set(actions)
    if not actions or actions == {"no-op"}:
        return None
    if actions == {"import"}:
        return "import"
    if "replace" in actions or actions == {"create", "delete"}:
        return "replace"
    if actions == {"create"}:
        return "create"
    if actions == {"delete"}:
        return "delete"
    if actions == {"update"}:
        return "update"
    if "delete" in actions and "create" in actions:
        return "replace"
    if "create" in actions:
        return "create"
    if "delete" in actions:
        return "delete"
    if "update" in actions:
        return "update"
    if "import" in actions:
        return "import"
    return None


def extract_resource(obj):
    """Pull the resource dict out of a planned_change ("change") or
    apply_start/apply_complete ("hook") line, whichever is present.
    Defensive against nested values that aren't dicts — a malformed or
    unexpected schema variant must not crash the script."""
    container = obj.get("change")
    if not isinstance(container, dict):
        container = obj.get("hook")
    if not isinstance(container, dict):
        container = {}
    resource = container.get("resource")
    if not isinstance(resource, dict):
        resource = {}
    action_field = container.get("action")
    return resource, action_field


def main():
    args = sys.argv[1:]
    if len(args) > 2:
        print(
            "usage: parse-tf-plan.py [plan.jsonl] [expected-shape.json]",
            file=sys.stderr,
        )
        sys.exit(2)

    input_path = args[0] if len(args) >= 1 else None
    expected_path = args[1] if len(args) >= 2 else None

    lines = read_lines(input_path)

    # Per-address dedup: a real `terraform apply -json` stream emits BOTH
    # planned_change (plan phase) and apply_start/apply_complete (apply
    # phase) lines for the same resource in the same run. Tallying every
    # line double-counts every resource against a change_summary that only
    # reflects the plan-phase count once. Track one (resource_type, bucket)
    # per address instead of incrementing counters per line seen.
    by_address = {}
    # Lines with a recognized action but no address at all (schema variant
    # without one) can't be deduped — tally them directly, best-effort.
    no_address_type_counts = Counter()
    no_address_action_counts = Counter()

    change_summary = None
    skipped_lines = 0       # JSON parse failures or non-dict top-level lines
    incomplete_lines = 0    # recognized line type, but missing resource_type/addr
    total_lines = 0
    recognized_lines = 0    # planned_change/apply_*/change_summary lines seen

    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        total_lines += 1
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            skipped_lines += 1
            continue
        if not isinstance(obj, dict):
            skipped_lines += 1
            continue

        line_type = obj.get("type")

        if line_type in ("planned_change", "apply_start", "apply_complete"):
            recognized_lines += 1
            resource, action_field = extract_resource(obj)
            resource_type = resource.get("resource_type")
            addr = resource.get("addr") or resource.get("resource")
            bucket = classify_change_line(normalize_actions(action_field))
            if bucket is None:
                continue
            if not resource_type or not addr:
                incomplete_lines += 1
            if addr:
                # Overwrite is safe: plan and apply phases report the same
                # classification for a given address within one run.
                by_address[addr] = (resource_type, bucket)
            elif resource_type:
                no_address_type_counts[resource_type] += 1
                no_address_action_counts[bucket] += 1
            else:
                no_address_action_counts[bucket] += 1

        elif line_type == "change_summary":
            recognized_lines += 1
            changes = obj.get("changes")
            if isinstance(changes, dict):
                change_summary = changes

        # All other line types (e.g. "diagnostic", "version", "resource_drift",
        # "apply_progress") are informational and not tallied.

    if total_lines == 0:
        print("error: no input lines to parse (empty input)", file=sys.stderr)
        sys.exit(2)

    if skipped_lines == total_lines:
        print(
            f"error: all {total_lines} line(s) were unparseable as Terraform "
            "JSON log objects — no valid content found",
            file=sys.stderr,
        )
        sys.exit(2)

    resource_type_counts = Counter(no_address_type_counts)
    action_counts = Counter(no_address_action_counts)
    addresses_seen = set(by_address.keys())
    for addr, (resource_type, bucket) in by_address.items():
        if resource_type:
            resource_type_counts[resource_type] += 1
        action_counts[bucket] += 1

    own_add = action_counts.get("create", 0) + action_counts.get("replace", 0)
    own_change = action_counts.get("update", 0)
    own_remove = action_counts.get("delete", 0) + action_counts.get("replace", 0)
    own_import = action_counts.get("import", 0)

    mismatches = []

    print("=== Resource type tally ===")
    if resource_type_counts:
        for rtype, count in sorted(resource_type_counts.items()):
            print(f"  {rtype}: {count}")
    else:
        print("  (no planned_change/apply lines found)")

    print()
    print("=== Action tally ===")
    if action_counts:
        for action in ("create", "update", "delete", "replace", "import"):
            if action_counts.get(action):
                print(f"  {action}: {action_counts[action]}")
    else:
        print("  (none)")

    print()
    print("=== Totals vs change_summary ===")
    print(
        f"  own tally:      add={own_add} change={own_change} "
        f"remove={own_remove} import={own_import}"
    )
    if change_summary is not None:
        official_add = change_summary.get("add", 0)
        official_change = change_summary.get("change", 0)
        official_remove = change_summary.get("remove", 0)
        official_import = change_summary.get("import", 0)
        print(
            f"  change_summary: add={official_add} change={official_change} "
            f"remove={official_remove} import={official_import}"
        )
        if (own_add, own_change, own_remove, own_import) != (
            official_add,
            official_change,
            official_remove,
            official_import,
        ):
            mismatches.append(
                "Tally mismatch against change_summary: "
                f"own(add={own_add}, change={own_change}, remove={own_remove}, "
                f"import={own_import}) != reported(add={official_add}, "
                f"change={official_change}, remove={official_remove}, "
                f"import={official_import})"
            )
    else:
        print("  (no change_summary line found in input)")

    if skipped_lines:
        print()
        print(f"note: skipped {skipped_lines} unparseable line(s) out of {total_lines}")
    if incomplete_lines:
        print(
            f"note: {incomplete_lines} recognized line(s) were missing a "
            "resource_type or address — action tally is complete but the "
            "resource-type tally may undercount these"
        )
    if total_lines and recognized_lines == 0:
        print(
            "note: no planned_change/apply/change_summary lines were "
            "recognized in this input — nothing to tally"
        )

    if expected_path:
        try:
            with open(expected_path, "r", encoding="utf-8") as f:
                expected = json.load(f)
        except OSError as exc:
            print(f"error: could not read {expected_path}: {exc}", file=sys.stderr)
            sys.exit(2)
        except json.JSONDecodeError as exc:
            print(f"error: {expected_path} is not valid JSON: {exc}", file=sys.stderr)
            sys.exit(2)

        if not isinstance(expected, dict):
            print(
                f"error: {expected_path} must contain a JSON object at the "
                f"top level, got {type(expected).__name__}",
                file=sys.stderr,
            )
            sys.exit(2)

        print()
        print("=== Expected shape diff ===")

        expected_resource_counts = expected.get("resource_counts", {})
        if not isinstance(expected_resource_counts, dict):
            print(
                f"error: {expected_path}'s resource_counts must be an object",
                file=sys.stderr,
            )
            sys.exit(2)
        for rtype, expected_count in expected_resource_counts.items():
            actual_count = resource_type_counts.get(rtype, 0)
            if actual_count != expected_count:
                msg = (
                    f"resource_counts[{rtype}]: expected {expected_count}, "
                    f"got {actual_count}"
                )
                mismatches.append(msg)
                print(f"  MISMATCH: {msg}")
            else:
                print(f"  ok: {rtype} = {actual_count}")

        must_include = expected.get("must_include", [])
        if not isinstance(must_include, list):
            print(
                f"error: {expected_path}'s must_include must be an array",
                file=sys.stderr,
            )
            sys.exit(2)
        for addr in must_include:
            if addr not in addresses_seen:
                msg = f"must_include violation: {addr} not found in plan"
                mismatches.append(msg)
                print(f"  MISMATCH: {msg}")
            else:
                print(f"  ok: {addr} present")

        must_exclude = expected.get("must_exclude", [])
        if not isinstance(must_exclude, list):
            print(
                f"error: {expected_path}'s must_exclude must be an array",
                file=sys.stderr,
            )
            sys.exit(2)
        for addr in must_exclude:
            if addr in addresses_seen:
                msg = f"must_exclude violation: {addr} found in plan"
                mismatches.append(msg)
                print(f"  MISMATCH: {msg}")
            else:
                print(f"  ok: {addr} absent")

        if not (expected_resource_counts or must_include or must_exclude):
            print("  (expected-shape file has none of resource_counts/must_include/must_exclude)")

    print()
    if mismatches:
        print(f"RESULT: FAIL — {len(mismatches)} mismatch(es)")
        sys.exit(1)
    print("RESULT: OK — no mismatches")
    sys.exit(0)


if __name__ == "__main__":
    main()
