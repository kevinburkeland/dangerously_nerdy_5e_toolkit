#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import tempfile


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


def _normalize_test_path(raw_path):
    p = raw_path.replace("\\", "/")
    if "/test/" in p:
        return "test/" + p.split("/test/", 1)[1]
    if p.startswith("./"):
        return p[2:]
    return p


def cmd_weights_from_reports(args):
    if len(args) != 2:
        print("Error: 'weights-from-reports' requires 2 arguments: <dir> <out>", file=sys.stderr)
        sys.exit(1)

    report_dir, out_path = args[0], args[1]
    if not os.path.isdir(report_dir):
        print(f"Error: Report directory not found: '{report_dir}'", file=sys.stderr)
        sys.exit(1)

    report_files = sorted(
        os.path.join(report_dir, fn)
        for fn in os.listdir(report_dir)
        if fn.endswith(".json")
    )
    if not report_files:
        print(f"Error: No .json report files found in '{report_dir}'", file=sys.stderr)
        sys.exit(1)

    weights = {}
    shard_seconds = []

    for rpath in report_files:
        suites = {}
        test_to_suite = {}
        loading_start = {}
        last_done = {}
        max_time_ms = 0

        with open(rpath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = ev.get("time")
                if isinstance(t, (int, float)) and t > max_time_ms:
                    max_time_ms = t

                ev_type = ev.get("type")
                if ev_type == "suite":
                    suite = ev.get("suite") or {}
                    sid = suite.get("id")
                    spath = suite.get("path")
                    if sid is not None and spath:
                        suites[sid] = _normalize_test_path(spath)
                elif ev_type == "testStart":
                    test = ev.get("test") or {}
                    tid = test.get("id")
                    sid = test.get("suiteID")
                    name = test.get("name") or ""
                    if tid is not None and sid is not None:
                        test_to_suite[tid] = sid
                        if isinstance(t, (int, float)):
                            if name.startswith("loading ") or sid not in loading_start:
                                if name.startswith("loading ") or t < loading_start[sid]:
                                    loading_start[sid] = t
                elif ev_type == "testDone":
                    tid = ev.get("testID")
                    sid = test_to_suite.get(tid)
                    if sid is not None and isinstance(t, (int, float)):
                        if sid not in last_done or t > last_done[sid]:
                            last_done[sid] = t

        shard_seconds.append(round(max_time_ms / 1000.0, 1))
        for sid, rel_path in suites.items():
            if sid in loading_start and sid in last_done:
                dur = max(0.1, round((last_done[sid] - loading_start[sid]) / 1000.0, 1))
                weights[rel_path] = dur

    out_dir = os.path.dirname(os.path.abspath(out_path))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(weights.items())), f, indent=2)
        f.write("\n")

    avg = sum(shard_seconds) / len(shard_seconds) if shard_seconds else 0.0
    ratio = round(max(shard_seconds) / avg, 2) if avg > 0 else 1.0
    shards_str = ", ".join(f"{s:.1f}s" for s in shard_seconds)
    print(f"shards: {shards_str} | slowest/avg: {ratio:.2f}")


def cmd_refresh_weights(args):
    if len(args) not in (1, 2):
        print("Error: 'refresh-weights' requires <run-id> [out-path]", file=sys.stderr)
        sys.exit(1)

    run_id = args[0]
    out_path = args[1] if len(args) == 2 else os.path.join("test", "shard_weights.json")

    with tempfile.TemporaryDirectory() as tmp:
        res = subprocess.run(
            ["gh", "run", "download", run_id, "-n", "shard-weights", "-D", tmp],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            print(f"Error: gh run download failed: {res.stderr.strip()}", file=sys.stderr)
            sys.exit(1)
        downloaded = os.path.join(tmp, "shard_weights.json")
        if not os.path.isfile(downloaded):
            print(f"Error: shard_weights.json not found in artifact for run {run_id}", file=sys.stderr)
            sys.exit(1)
        with open(downloaded, "r", encoding="utf-8") as src:
            content = src.read()
        out_dir = os.path.dirname(os.path.abspath(out_path))
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as dst:
            dst.write(content)
    print(f"Refreshed {out_path} from run {run_id}")


def main():
    if len(sys.argv) < 2:
        print("Error: Missing command. Usage: scripts/test_shard.py <list|check|check-workflow|weights-from-reports|refresh-weights> [args...]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "list":
        cmd_list(args)
    elif cmd == "check":
        cmd_check(args)
    elif cmd == "check-workflow":
        cmd_check_workflow(args)
    elif cmd == "weights-from-reports":
        cmd_weights_from_reports(args)
    elif cmd == "refresh-weights":
        cmd_refresh_weights(args)
    else:
        print(f"Error: Unknown command '{cmd}'. Usage: scripts/test_shard.py <list|check|check-workflow|weights-from-reports|refresh-weights> [args...]", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
