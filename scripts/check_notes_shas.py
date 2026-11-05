#!/usr/bin/env python3
import sys
import os
import re
import argparse
import subprocess
import urllib.request
import urllib.error
import json


def is_git_repo(path):
    if not os.path.isdir(path):
        return False
    res = subprocess.run(['git', '-C', path, 'rev-parse', '--git-dir'],
                         capture_output=True, text=True)
    return res.returncode == 0


def is_commit_in_repo(repo, sha):
    res = subprocess.run(['git', '-C', repo, 'cat-file', '-e', f'{sha}^{{commit}}'],
                         capture_output=True, text=True)
    return res.returncode == 0


def main():
    parser = argparse.ArgumentParser(description='Check commit SHAs and CI run IDs in notes files.')
    parser.add_argument('--repo', action='append', required=True,
                        help='Path to a git repository (optionally PATH=OWNER/NAME) to verify commits against')
    parser.add_argument('--api-base', default='https://api.github.com',
                        help='Base URL for GitHub API (default: https://api.github.com)')
    parser.add_argument('files', nargs='+', help='Files to check')

    args = parser.parse_args()

    repo_entries = []
    has_any_github_name = False

    for entry in args.repo:
        if '=' in entry:
            path, github_name = entry.split('=', 1)
            has_any_github_name = True
        else:
            path, github_name = entry, None
        if not is_git_repo(path):
            print(f"Error: '{path}' is not a valid git repository.", file=sys.stderr)
            sys.exit(1)
        repo_entries.append({'path': path, 'github_name': github_name})

    # If --api-base was changed from default, also consider run verification active
    if args.api_base != 'https://api.github.com':
        has_any_github_name = True

    hex_pattern = re.compile(r'(?<![0-9a-zA-Z])([0-9a-fA-F]+)(?![0-9a-zA-Z])')
    orphan_pattern = re.compile(r'(?<![0-9a-zA-Z])run\s+([0-9]{6,})(?![0-9])')
    claim_pattern = re.compile(r'(?<![0-9a-fA-F])([0-9a-fA-F]{40}) run ([0-9]+)(?![0-9])')

    problems = []
    total_shas_checked = 0
    total_runs_checked = 0
    total_files_checked = len(args.files)

    # Cache commit verification across multiple occurrences: sha -> repo_entry
    verified_commits = {}
    failed_commits = set()

    # Cache GitHub API run lookups: (owner_repo, run_id) -> (status_code, json_or_err)
    run_cache = {}

    headers = {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'check_notes_shas',
    }
    github_token = os.environ.get('GITHUB_TOKEN')
    if github_token:
        headers['Authorization'] = f'Bearer {github_token}'

    for file_path in args.files:
        if not os.path.isfile(file_path):
            problems.append(f"{file_path}:1: File does not exist")
            continue

        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()

        for line_idx, line in enumerate(lines, 1):
            # 1. SHA verification
            for match in hex_pattern.finditer(line):
                hex_str = match.group(1)
                length = len(hex_str)

                if length < 40:
                    continue

                total_shas_checked += 1

                if length > 40:
                    problems.append(f"{file_path}:{line_idx}: {hex_str} is longer than 40 characters")
                    continue

                sha = hex_str.lower()
                if sha in verified_commits:
                    continue
                if sha in failed_commits:
                    problems.append(f"{file_path}:{line_idx}: {hex_str} is not a commit in any given repo")
                    continue

                found_repo = None
                for r in repo_entries:
                    if is_commit_in_repo(r['path'], sha):
                        found_repo = r
                        verified_commits[sha] = r
                        break

                if not found_repo:
                    failed_commits.add(sha)
                    problems.append(f"{file_path}:{line_idx}: {hex_str} is not a commit in any given repo")

            # 2. Orphan run id check (when run verification is active)
            if has_any_github_name:
                for match in orphan_pattern.finditer(line):
                    start = match.start()
                    is_after_sha = False
                    if start >= 41:
                        preceding = line[start - 41:start]
                        if preceding.endswith(' '):
                            cand_sha = preceding[:40]
                            if re.fullmatch(r'[0-9a-fA-F]{40}', cand_sha):
                                if start == 41 or not re.match(r'[0-9a-fA-F]', line[start - 42]):
                                    is_after_sha = True
                    if not is_after_sha:
                        problems.append(f"{file_path}:{line_idx}: run id without its head SHA")

            # 3. Run claims verification
            for match in claim_pattern.finditer(line):
                sha = match.group(1).lower()
                run_id = match.group(2)
                total_runs_checked += 1

                # Find repo holding this SHA
                repo = verified_commits.get(sha)
                if not repo:
                    for r in repo_entries:
                        if is_commit_in_repo(r['path'], sha):
                            repo = r
                            verified_commits[sha] = r
                            break

                if not repo:
                    # Commit check already failed or will fail for this SHA
                    continue

                if not repo['github_name']:
                    problems.append(f"{file_path}:{line_idx}: no GitHub name for repo {repo['path']}")
                    continue

                owner_repo = repo['github_name']
                url = f"{args.api_base.rstrip('/')}/repos/{owner_repo}/actions/runs/{run_id}"

                cache_key = (owner_repo, run_id)
                if cache_key in run_cache:
                    status_code, data_or_err = run_cache[cache_key]
                else:
                    req = urllib.request.Request(url, headers=headers)
                    try:
                        with urllib.request.urlopen(req, timeout=15) as resp:
                            status_code = resp.getcode()
                            body = resp.read().decode('utf-8')
                            data_or_err = json.loads(body)
                            run_cache[cache_key] = (status_code, data_or_err)
                    except urllib.error.HTTPError as e:
                        status_code = e.code
                        try:
                            body = e.read().decode('utf-8')
                            data_or_err = json.loads(body)
                        except Exception:
                            data_or_err = None
                        run_cache[cache_key] = (status_code, data_or_err)
                    except Exception as e:
                        status_code = 0
                        data_or_err = str(e)
                        run_cache[cache_key] = (status_code, data_or_err)

                if status_code == 404:
                    problems.append(f"{file_path}:{line_idx}: run {run_id}: not found")
                elif status_code == 200 and isinstance(data_or_err, dict):
                    head_sha = str(data_or_err.get('head_sha', '')).lower()
                    conclusion = data_or_err.get('conclusion')
                    if head_sha != sha:
                        problems.append(f"{file_path}:{line_idx}: run {run_id}: head_sha is {head_sha}")
                    elif conclusion != 'success':
                        problems.append(f"{file_path}:{line_idx}: run {run_id}: conclusion is {conclusion}")
                else:
                    err_msg = f"HTTP {status_code}" if status_code else str(data_or_err)
                    problems.append(f"{file_path}:{line_idx}: run {run_id}: could not verify run {run_id} ({err_msg})")

    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        print(f"Checked {total_files_checked} file(s), {total_shas_checked} SHA(s), and {total_runs_checked} run id(s) checked. Found {len(problems)} problem(s).", file=sys.stderr)
        sys.exit(1)

    print(f"Checked {total_files_checked} file(s), {total_shas_checked} SHA(s), and {total_runs_checked} run id(s) checked. All SHAs are valid commits.")
    sys.exit(0)


if __name__ == '__main__':
    main()
