#!/usr/bin/env python3
"""Verify all CI job results match the decided scope ('full' or 'notes-only')."""

import argparse
import sys

HEAVY_JOBS = {
    "analyze",
    "dependencies",
    "test",
    "web-tests",
    "tests-complete",
    "firestore-rules",
    "build-web",
}
LIGHT_JOBS = {"notes-text-checks"}
ALWAYS_JOBS = {"scope", "dco", "notes-shas"}


def evaluate_results(scope, job_results):
    problems = []
    if scope not in ("full", "notes-only"):
        problems.append(f"invalid scope '{scope}' (expected 'full' or 'notes-only')")

    for job in sorted(ALWAYS_JOBS):
        res = job_results.get(job)
        if res != "success":
            problems.append(f"required job '{job}' has result '{res}' (expected 'success')")

    for job in sorted(HEAVY_JOBS):
        res = job_results.get(job)
        if scope == "full":
            if res != "success":
                problems.append(f"heavy job '{job}' on scope=full has result '{res}' (expected 'success')")
        elif scope == "notes-only":
            if res != "skipped":
                problems.append(f"heavy job '{job}' on scope=notes-only has result '{res}' (expected 'skipped')")

    for job in sorted(LIGHT_JOBS):
        res = job_results.get(job)
        if scope == "notes-only":
            if res != "success":
                problems.append(f"light job '{job}' on scope=notes-only has result '{res}' (expected 'success')")
        elif scope == "full":
            if res != "skipped":
                problems.append(f"light job '{job}' on scope=full has result '{res}' (expected 'skipped')")

    return problems


def main():
    parser = argparse.ArgumentParser(description="Verify CI job results against scope.")
    parser.add_argument("--scope", required=True)
    parser.add_argument("--job", action="append", default=[], help="name=result")
    args = parser.parse_args()

    job_results = {}
    for entry in args.job:
        if "=" not in entry:
            print(f"Error: invalid --job entry '{entry}'", file=sys.stderr)
            sys.exit(1)
        name, val = entry.split("=", 1)
        job_results[name] = val

    print(f"scope={args.scope}")
    for name in sorted(job_results):
        print(f"  {name}: {job_results[name]}")

    problems = evaluate_results(args.scope, job_results)
    if problems:
        for p in problems:
            print(f"FAIL: {p}", file=sys.stderr)
        sys.exit(1)
    print("OK: all job results match scope")


if __name__ == "__main__":
    main()
