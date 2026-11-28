#!/usr/bin/env python3
"""Decide CI scope ('full' or 'notes-only') fail-closed from git diff and parent workflow status."""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


def decide_scope(
    *,
    event_name,
    ref,
    changed_files,
    parent_count,
    parent_sha,
    runs,
    workflow_name,
    has_token,
):
    if event_name != "push" or ref != "refs/heads/main":
        return "full", f"scope=full reason=event({event_name})_or_ref({ref})"
    if parent_count != 1 or not parent_sha:
        return "full", f"scope=full reason=not_single_parent(count={parent_count})"
    if not changed_files:
        return "full", "scope=full reason=no_changed_files"
    non_notes = [f for f in changed_files if not f.startswith("notes/")]
    if non_notes:
        return "full", f"scope=full reason=non_notes_changed({','.join(non_notes[:5])})"
    if not has_token:
        return "full", "scope=full reason=missing_token"
    if runs is None:
        return "full", "scope=full reason=api_lookup_failed"

    parent_lower = parent_sha.lower()
    wf_base = os.path.basename(workflow_name) if workflow_name else ""
    for r in runs:
        if str(r.get("head_sha", "")).lower() != parent_lower:
            continue
        if r.get("status") != "completed" or r.get("conclusion") != "success":
            continue
        r_path = str(r.get("path", ""))
        if wf_base and r_path and os.path.basename(r_path) != wf_base:
            continue
        run_id = r.get("id")
        if run_id is not None:
            return (
                "notes-only",
                f"scope=notes-only parent={parent_sha} parent_run={run_id} changed={','.join(changed_files)}",
            )

    return "full", f"scope=full reason=no_green_parent_run(parent={parent_sha})"


def get_git_info(repo_path):
    res = subprocess.run(
        ["git", "-C", repo_path, "rev-list", "--parents", "-n", "1", "HEAD"],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        return 0, None, []
    parts = res.stdout.strip().split()
    if len(parts) != 2:
        return len(parts) - 1, None, []
    parent_sha = parts[1]
    diff_res = subprocess.run(
        ["git", "-C", repo_path, "diff", "--name-only", f"{parent_sha}..HEAD"],
        capture_output=True,
        text=True,
    )
    if diff_res.returncode != 0:
        return 1, parent_sha, []
    changed = [line.strip() for line in diff_res.stdout.splitlines() if line.strip()]
    return 1, parent_sha, changed


def fetch_parent_runs(api_base, owner_repo, parent_sha, token):
    url = (
        f"{api_base.rstrip('/')}/repos/{owner_repo}/actions/runs"
        f"?branch=main&head_sha={urllib.parse.quote(parent_sha)}&per_page=20"
    )
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "ci_scope",
        "Authorization": f"Bearer {token}",
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.getcode() != 200:
                return None
            data = json.loads(resp.read().decode("utf-8"))
            runs = data.get("workflow_runs")
            if isinstance(runs, list):
                return runs
            return None
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, OSError):
        return None


def main():
    parser = argparse.ArgumentParser(description="Decide CI scope (full or notes-only).")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--owner-repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--ref", default=os.environ.get("GITHUB_REF", ""))
    parser.add_argument("--workflow", default="release.yml")
    parser.add_argument("--api-base", default=os.environ.get("GITHUB_API_URL", "https://api.github.com"))
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    args = parser.parse_args()

    token = os.environ.get("GITHUB_TOKEN", "")
    parent_count, parent_sha, changed = get_git_info(args.repo)

    runs = None
    if (
        args.event == "push"
        and args.ref == "refs/heads/main"
        and parent_count == 1
        and parent_sha
        and changed
        and all(f.startswith("notes/") for f in changed)
        and token
        and args.owner_repo
    ):
        runs = fetch_parent_runs(args.api_base, args.owner_repo, parent_sha, token)

    scope, line = decide_scope(
        event_name=args.event,
        ref=args.ref,
        changed_files=changed,
        parent_count=parent_count,
        parent_sha=parent_sha,
        runs=runs,
        workflow_name=args.workflow,
        has_token=bool(token),
    )

    print(line)
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as f:
            f.write(f"scope={scope}\n")


if __name__ == "__main__":
    main()
