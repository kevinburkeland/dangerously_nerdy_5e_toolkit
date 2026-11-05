#!/usr/bin/env python3
import sys
import os
import re


def find_test_files(root_dir="test"):
    if not os.path.isdir(root_dir):
        return []
    test_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if fname.endswith("_test.dart"):
                rel_path = os.path.join(dirpath, fname).replace(os.sep, "/")
                test_files.append(rel_path)
    test_files.sort(key=lambda p: p.encode("utf-8"))
    return test_files


def shard_files(files, index, total):
    return [f for pos, f in enumerate(files) if pos % total == index]


def parse_int(val, name):
    try:
        # Check that string consists only of digits (or optional leading sign)
        # to reject floats like "1.5"
        val_int = int(val)
        if str(val_int) != val.strip():
            # e.g. float or formatted number
            pass
        return val_int
    except ValueError:
        print(f"Error: {name} must be a whole number, got: '{val}'", file=sys.stderr)
        sys.exit(1)


def cmd_list(args):
    if len(args) != 2:
        print("Error: 'list' requires 2 arguments: <index> <total>", file=sys.stderr)
        sys.exit(1)

    index = parse_int(args[0], "index")
    total = parse_int(args[1], "total")

    if total < 1:
        print(f"Error: total must be >= 1, got: {total}", file=sys.stderr)
        sys.exit(1)
    if index < 0:
        print(f"Error: index must be >= 0, got: {index}", file=sys.stderr)
        sys.exit(1)
    if index >= total:
        print(f"Error: index ({index}) must be < total ({total})", file=sys.stderr)
        sys.exit(1)

    files = find_test_files("test")
    selected = shard_files(files, index, total)
    for f in selected:
        print(f)


def cmd_check(args):
    if len(args) != 1:
        print("Error: 'check' requires 1 argument: <total>", file=sys.stderr)
        sys.exit(1)

    total = parse_int(args[0], "total")
    if total < 1:
        print(f"Error: total must be >= 1, got: {total}", file=sys.stderr)
        sys.exit(1)

    files = find_test_files("test")
    if not files:
        print("Error: No test files found under test/", file=sys.stderr)
        sys.exit(1)

    shards = [shard_files(files, i, total) for i in range(total)]

    seen = set()
    union = []
    for i, s in enumerate(shards):
        print(f"shard {i}: {len(s)} files")
        for f in s:
            if f in seen:
                print(f"Error: File appears in multiple shards: {f}", file=sys.stderr)
                sys.exit(1)
            seen.add(f)
            union.append(f)

    if sorted(union, key=lambda p: p.encode("utf-8")) != files:
        print("Error: Union of shards does not match full sorted test list", file=sys.stderr)
        sys.exit(1)

    print(f"total: {len(files)} files in {total} shards")


def cmd_check_workflow(args):
    if len(args) != 1:
        print("Error: 'check-workflow' requires 1 argument: <path-to-workflow>", file=sys.stderr)
        sys.exit(1)

    workflow_path = args[0]
    if not os.path.isfile(workflow_path):
        print(f"Error: File not found: '{workflow_path}'", file=sys.stderr)
        sys.exit(1)

    with open(workflow_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    call_lines = []
    for line in lines:
        if "scripts/test_shard.py list" in line:
            call_lines.append(line)

    if len(call_lines) == 0:
        print(f"Error: No call of 'scripts/test_shard.py list' found in {workflow_path}", file=sys.stderr)
        sys.exit(1)

    if len(call_lines) > 1:
        print(f"Error: Expected exactly one call of 'scripts/test_shard.py list', found {len(call_lines)} in {workflow_path}", file=sys.stderr)
        sys.exit(1)

    found_line = call_lines[0].strip()
    # Check that arguments directly after list are exactly ${{ strategy.job-index }} and ${{ strategy.job-total }}
    pattern = re.compile(
        r'scripts/test_shard\.py\s+list\s+\${{\s*strategy\.job-index\s*}}\s+\${{\s*strategy\.job-total\s*}}(?:\s+|$)'
    )
    if not pattern.search(found_line):
        print(f"Error: scripts/test_shard.py list call has incorrect arguments: {found_line}", file=sys.stderr)
        sys.exit(1)

    print(found_line)


def main():
    if len(sys.argv) < 2:
        print("Error: Missing command. Usage: scripts/test_shard.py <list|check|check-workflow> [args...]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "list":
        cmd_list(args)
    elif cmd == "check":
        cmd_check(args)
    elif cmd == "check-workflow":
        cmd_check_workflow(args)
    else:
        print(f"Error: Unknown command '{cmd}'. Usage: scripts/test_shard.py <list|check|check-workflow> [args...]", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
