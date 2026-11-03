#!/usr/bin/env python3
import sys
import os
import re
import argparse
import subprocess


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
    parser = argparse.ArgumentParser(description='Check commit SHAs in notes files.')
    parser.add_argument('--repo', action='append', required=True,
                        help='Path to a git repository to verify commits against')
    parser.add_argument('files', nargs='+', help='Files to check')

    args = parser.parse_args()

    for repo in args.repo:
        if not is_git_repo(repo):
            print(f"Error: '{repo}' is not a valid git repository.", file=sys.stderr)
            sys.exit(1)

    hex_pattern = re.compile(r'(?<![0-9a-zA-Z])([0-9a-fA-F]+)(?![0-9a-zA-Z])')

    problems = []
    total_shas_checked = 0
    total_files_checked = len(args.files)

    # Cache commit verification across multiple occurrences
    verified_commits = set()
    failed_commits = set()

    for file_path in args.files:
        if not os.path.isfile(file_path):
            problems.append(f"{file_path}:1: File does not exist")
            continue

        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()

        for line_idx, line in enumerate(lines, 1):
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

                found = False
                for repo in args.repo:
                    if is_commit_in_repo(repo, sha):
                        found = True
                        verified_commits.add(sha)
                        break

                if not found:
                    failed_commits.add(sha)
                    problems.append(f"{file_path}:{line_idx}: {hex_str} is not a commit in any given repo")

    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        print(f"Checked {total_files_checked} file(s) and {total_shas_checked} SHA(s). Found {len(problems)} problem(s).", file=sys.stderr)
        sys.exit(1)

    print(f"Checked {total_files_checked} file(s) and {total_shas_checked} SHA(s). All SHAs are valid commits.")
    sys.exit(0)


if __name__ == '__main__':
    main()
