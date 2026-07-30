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
    2 — usage / input error (bad args, unreadable file)
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
    ("create", "update", "delete", "replace", "no-op", "read") or, in some
    schema variants, a list of primitive actions (e.g. ["create", "delete"]
    for a create-before-destroy replace). Normalize to a list of strings."""
    if action_field is None:
        return []
    if isinstance(action_field, str):
        return [action_field]
    if isinstance(action_field, list):
        return [a for a in action_field if isinstance(a, str)]
    return []


def classify_change_line(actions):
    """Map a set of raw terraform actions to the add/change/remove buckets
    used in Terraform's own "Plan: N to add, M to change, K to destroy"
    summary. A replace is reported as one add + one destroy."""
    actions = set(actions)
    if actions == {"no-op"} or not actions:
        return None
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
    return None


def extract_resource(obj):
    """Pull the resource dict out of a planned_change ("change") or
    apply_start/apply_complete ("hook") line, whichever is present."""
    container = obj.get("change") or obj.get("hook") or {}
    resource = container.get("resource") or {}
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

    resource_type_counts = Counter()
    action_counts = Counter()
    addresses_seen = set()
    resource_type_by_address = {}
    change_summary = None
    skipped_lines = 0
    total_lines = 0

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

        if line_type == "planned_change":
            resource, action_field = extract_resource(obj)
            resource_type = resource.get("resource_type")
            addr = resource.get("addr") or resource.get("resource")
            bucket = classify_change_line(normalize_actions(action_field))
            if bucket is None:
                continue
            if resource_type:
                resource_type_counts[resource_type] += 1
                if addr:
                    resource_type_by_address[addr] = resource_type
            if addr:
                addresses_seen.add(addr)
            action_counts[bucket] += 1

        elif line_type in ("apply_start", "apply_complete"):
            resource, action_field = extract_resource(obj)
            resource_type = resource.get("resource_type")
            addr = resource.get("addr") or resource.get("resource")
            bucket = classify_change_line(normalize_actions(action_field))
            if line_type == "apply_start":
                if bucket is not None:
                    if resource_type:
                        resource_type_counts[resource_type] += 1
                        if addr:
                            resource_type_by_address[addr] = resource_type
                    if addr:
                        addresses_seen.add(addr)
                    action_counts[bucket] += 1

        elif line_type == "change_summary":
            changes = obj.get("changes")
            if isinstance(changes, dict):
                change_summary = changes

        # All other line types (e.g. "diagnostic", "version", "resource_drift",
        # "apply_progress") are informational and not tallied.

    own_add = action_counts.get("create", 0) + action_counts.get("replace", 0)
    own_change = action_counts.get("update", 0)
    own_remove = action_counts.get("delete", 0) + action_counts.get("replace", 0)

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
        for action in ("create", "update", "delete", "replace"):
            if action_counts.get(action):
                print(f"  {action}: {action_counts[action]}")
    else:
        print("  (none)")

    print()
    print("=== Totals vs change_summary ===")
    print(f"  own tally:      add={own_add} change={own_change} remove={own_remove}")
    if change_summary is not None:
        official_add = change_summary.get("add", 0)
        official_change = change_summary.get("change", 0)
        official_remove = change_summary.get("remove", 0)
        print(
            f"  change_summary: add={official_add} change={official_change} "
            f"remove={official_remove}"
        )
        if (own_add, own_change, own_remove) != (
            official_add,
            official_change,
            official_remove,
        ):
            mismatches.append(
                "Tally mismatch against change_summary: "
                f"own(add={own_add}, change={own_change}, remove={own_remove}) != "
                f"reported(add={official_add}, change={official_change}, "
                f"remove={official_remove})"
            )
    else:
        print("  (no change_summary line found in input)")

    if skipped_lines:
        print()
        print(f"note: skipped {skipped_lines} unparseable line(s) out of {total_lines}")

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

        print()
        print("=== Expected shape diff ===")

        expected_resource_counts = expected.get("resource_counts", {})
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
        for addr in must_include:
            if addr not in addresses_seen:
                msg = f"must_include violation: {addr} not found in plan"
                mismatches.append(msg)
                print(f"  MISMATCH: {msg}")
            else:
                print(f"  ok: {addr} present")

        must_exclude = expected.get("must_exclude", [])
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
