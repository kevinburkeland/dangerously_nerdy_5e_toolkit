#!/usr/bin/env python3
"""Verify the live notes SHA check configuration in a GitHub Actions workflow."""

import os
import re
import sys


REQUIRED_REPO_PAIRS = [
    ("dangerously_nerdy_5e_toolkit", "kevinburkeland/dangerously_nerdy_5e_toolkit"),
    ("vtt-engine-core", "kevinburkeland/vtt-engine-core"),
    ("vtt-ruleset-dnd5e", "kevinburkeland/vtt-ruleset-dnd5e"),
]


def parse_workflow_jobs(text):
    """Parse top-level jobs and their steps from a GitHub Actions workflow YAML."""
    jobs = {}
    lines = text.splitlines()
    in_jobs = False
    current_job = None
    in_steps = False
    current_step = None
    in_run_block = False
    run_indent = 0
    in_env_block = False
    env_indent = 0

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            if in_run_block and current_step is not None:
                current_step["run"] += "\n"
            continue

        indent = len(line) - len(line.lstrip(" "))

        if not in_jobs:
            if indent == 0 and stripped == "jobs:":
                in_jobs = True
            continue

        if indent == 0 and not stripped.startswith("-"):
            in_jobs = False
            continue

        if indent == 2 and stripped.endswith(":") and not stripped.startswith("-"):
            job_name = stripped[:-1].strip()
            current_job = {"name": job_name, "steps": [], "env": []}
            jobs[job_name] = current_job
            in_steps = False
            current_step = None
            in_run_block = False
            in_env_block = False
            continue

        if current_job is None:
            continue

        if indent == 4 and stripped == "steps:":
            in_steps = True
            current_step = None
            in_run_block = False
            in_env_block = False
            continue

        if not in_steps:
            continue

        if in_run_block:
            if indent > run_indent:
                current_step["run"] += line[run_indent:] + "\n"
                continue
            else:
                in_run_block = False

        if in_env_block:
            if indent > env_indent and not stripped.startswith("-"):
                current_step["env"].append(stripped)
                continue
            else:
                in_env_block = False

        if indent == 6 and stripped.startswith("- "):
            current_step = {"name": "", "run": "", "env": []}
            current_job["steps"].append(current_step)
            rest = stripped[2:].strip()
            if rest.startswith("name:"):
                current_step["name"] = rest[len("name:"):].strip()
            elif rest.startswith("run:"):
                val = rest[len("run:"):].strip()
                if val in ("|", "|-", "|+", ">", ">-"):
                    in_run_block = True
                    run_indent = indent + 2
                else:
                    current_step["run"] = val
            elif rest == "env:":
                in_env_block = True
                env_indent = indent + 2
            continue

        if current_step is None:
            continue

        if indent == 8:
            if stripped.startswith("name:"):
                current_step["name"] = stripped[len("name:"):].strip()
            elif stripped.startswith("run:"):
                val = stripped[len("run:"):].strip()
                if val in ("|", "|-", "|+", ">", ">-"):
                    in_run_block = True
                    run_indent = indent
                else:
                    current_step["run"] = val
            elif stripped == "env:":
                in_env_block = True
                env_indent = indent

    return jobs


def check_workflow(workflow_path):
    if not os.path.isfile(workflow_path):
        print(f"Error: File not found: '{workflow_path}'", file=sys.stderr)
        return 1

    with open(workflow_path, "r", encoding="utf-8") as f:
        text = f.read()

    jobs = parse_workflow_jobs(text)

    # 1. No notes step may remain in the dco job.
    dco_job = jobs.get("dco")
    if dco_job is not None:
        for step in dco_job["steps"]:
            run_text = step["run"]
            if "test_check_notes_shas.sh" in run_text or "check_notes_shas.py" in run_text:
                print(
                    f"Error: Notes step '{step['name']}' is still inside the 'dco' job in {workflow_path}",
                    file=sys.stderr,
                )
                return 1

    # 2. Exactly one step across the workflow runs the live check_notes_shas.py.
    live_steps = []
    for job_name, job in jobs.items():
        for step in job["steps"]:
            if re.search(r"scripts/check_notes_shas\.py\b", step["run"]):
                live_steps.append((job_name, step))

    if len(live_steps) == 0:
        print(
            f"Error: No live 'scripts/check_notes_shas.py' step found in {workflow_path}",
            file=sys.stderr,
        )
        return 1

    if len(live_steps) > 1:
        print(
            f"Error: Expected exactly 1 live 'scripts/check_notes_shas.py' step, found {len(live_steps)} in {workflow_path}",
            file=sys.stderr,
        )
        return 1

    _, live_step = live_steps[0]
    run_cmd = live_step["run"]

    # 3. GITHUB_TOKEN must be set in the step's env.
    has_token = any(re.match(r"GITHUB_TOKEN\s*:", e) for e in live_step["env"])
    if not has_token:
        print(
            f"Error: Live notes step '{live_step['name']}' is missing GITHUB_TOKEN env in {workflow_path}",
            file=sys.stderr,
        )
        return 1

    # 4. All three --repo pairs must be present.
    for _, slug in REQUIRED_REPO_PAIRS:
        if not re.search(rf'--repo\s+"?[^\s"=]+={re.escape(slug)}"?(?:\s|$)', run_cmd):
            print(
                f"Error: Live notes step is missing --repo pair for '{slug}' in {workflow_path}",
                file=sys.stderr,
            )
            return 1

    # 5. Must run over notes/*.md.
    if not re.search(r"(?:^|\s)notes/\*\.md(?:\s|$)", run_cmd):
        print(
            f"Error: Live notes step must run over 'notes/*.md' in {workflow_path}",
            file=sys.stderr,
        )
        return 1

    print(f"OK: 1 live notes check step verified in {workflow_path}")
    return 0


def main():
    if len(sys.argv) != 2:
        print("Usage: scripts/check_notes_workflow.py <path-to-workflow>", file=sys.stderr)
        sys.exit(1)
    sys.exit(check_workflow(sys.argv[1]))


if __name__ == "__main__":
    main()
