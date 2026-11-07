#!/usr/bin/env python3
import sys
import os
import re
import argparse
import subprocess
import urllib.request
import urllib.error
import json
from datetime import datetime, timezone


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


def get_commit_date(repo, sha):
    res = subprocess.run(['git', '-C', repo, 'log', '-1', '--format=%cI', sha],
                         capture_output=True, text=True)
    if res.returncode == 0 and res.stdout.strip():
        try:
            return datetime.fromisoformat(res.stdout.strip())
        except Exception:
            return None
    return None


RED_CONCLUSIONS = {'failure', 'timed_out', 'startup_failure', 'action_required'}


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

    if args.api_base != 'https://api.github.com':
        has_any_github_name = True

    hex_pattern = re.compile(r'(?<![0-9a-zA-Z])([0-9a-fA-F]+)(?![0-9a-zA-Z])')
    claim_pattern = re.compile(r'(?<![0-9a-fA-F])([0-9a-fA-F]{40}) run ([0-9]+)(?![0-9])')
    red_claim_pattern = re.compile(r'(?<![0-9a-fA-F])([0-9a-fA-F]{40}) red run ([0-9]+)(?![0-9])')

    mention_pattern = re.compile(r'(?i)(?<![a-zA-Z])runs?[^a-zA-Z0-9\n]{1,3}([0-9]{6,})(?![0-9])')
    sha_mention_pattern = re.compile(r'(?i)(?<![0-9a-fA-F])([0-9a-fA-F]{40})[^a-zA-Z0-9\n]+runs?[^a-zA-Z0-9\n]{1,3}([0-9]+)(?![0-9])')

    problems = []
    total_shas_checked = 0
    total_runs_checked = 0
    total_red_runs_checked = 0
    total_ranges_checked = 0
    total_files_checked = len(args.files)
    total_fix_checklists_checked = 0
    total_fix_ids_checked = 0

    verified_commits = {}
    failed_commits = set()
    run_cache = {}
    repo_runs_cache = {}

    headers = {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'check_notes_shas',
    }
    github_token = os.environ.get('GITHUB_TOKEN')
    if github_token:
        headers['Authorization'] = f'Bearer {github_token}'

    def fetch_run(owner_repo, run_id):
        cache_key = (owner_repo, str(run_id))
        if cache_key in run_cache:
            return run_cache[cache_key]

        url = f"{args.api_base.rstrip('/')}/repos/{owner_repo}/actions/runs/{run_id}"
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                status_code = resp.getcode()
                body = resp.read().decode('utf-8')
                data_or_err = json.loads(body)
                run_cache[cache_key] = (status_code, data_or_err)
                return status_code, data_or_err
        except urllib.error.HTTPError as e:
            status_code = e.code
            try:
                body = e.read().decode('utf-8')
                data_or_err = json.loads(body)
            except Exception:
                data_or_err = None
            run_cache[cache_key] = (status_code, data_or_err)
            return status_code, data_or_err
        except Exception as e:
            status_code = 0
            data_or_err = str(e)
            run_cache[cache_key] = (status_code, data_or_err)
            return status_code, data_or_err

    def fetch_repo_runs(owner_repo, oldest_commit_date=None):
        if owner_repo in repo_runs_cache:
            return repo_runs_cache[owner_repo]

        all_runs = []
        page = 1
        while True:
            url = f"{args.api_base.rstrip('/')}/repos/{owner_repo}/actions/runs?branch=main&per_page=100&page={page}"
            req = urllib.request.Request(url, headers=headers)
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    status_code = resp.getcode()
                    if status_code != 200:
                        repo_runs_cache[owner_repo] = (status_code, None)
                        return status_code, None
                    body = resp.read().decode('utf-8')
                    data = json.loads(body)
                    w_runs = data.get('workflow_runs', [])
                    if not w_runs and isinstance(data, list):
                        w_runs = data
                    all_runs.extend(w_runs)
                    for r in w_runs:
                        r_id = str(r.get('id', ''))
                        if r_id:
                            run_cache[(owner_repo, r_id)] = (200, r)

                    if len(w_runs) < 100:
                        break

                    if oldest_commit_date:
                        all_older = True
                        for r in w_runs:
                            c_at = r.get('created_at')
                            if c_at:
                                try:
                                    r_date = datetime.fromisoformat(c_at.replace('Z', '+00:00'))
                                    if r_date >= oldest_commit_date:
                                        all_older = False
                                        break
                                except Exception:
                                    all_older = False
                                    break
                            else:
                                all_older = False
                                break
                        if all_older:
                            break

                    page += 1
            except urllib.error.HTTPError as e:
                if page > 1 and e.code == 404:
                    break
                repo_runs_cache[owner_repo] = (e.code, None)
                return e.code, None
            except Exception as e:
                repo_runs_cache[owner_repo] = (0, str(e))
                return 0, str(e)

        repo_runs_cache[owner_repo] = (200, all_runs)
        return 200, all_runs

    def find_repo_for_sha(sha):
        sha_lower = sha.lower()
        if sha_lower in verified_commits:
            return verified_commits[sha_lower]
        for r in repo_entries:
            if is_commit_in_repo(r['path'], sha_lower):
                verified_commits[sha_lower] = r
                return r
        return None

    # First pass: check file existence and collect oldest start commit across all notes files
    oldest_start_date = None
    files_data = {}

    for file_path in args.files:
        if not os.path.isfile(file_path):
            problems.append(f"{file_path}:1: File does not exist")
            continue

        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
        files_data[file_path] = lines

        for line in lines:
            if line.startswith('Start heads:'):
                shas = hex_pattern.findall(line)
                for s in shas:
                    if len(s) == 40:
                        for r in repo_entries:
                            if is_commit_in_repo(r['path'], s):
                                d = get_commit_date(r['path'], s)
                                if d:
                                    if oldest_start_date is None or d < oldest_start_date:
                                        oldest_start_date = d

    # Pre-fetch runs for repos with github_name if run verification active and any file has slice metadata
    any_has_slice_metadata = any(
        ('Status:' in ''.join(lines) or 'Start heads:' in ''.join(lines))
        for lines in files_data.values()
    )
    if has_any_github_name and any_has_slice_metadata:
        for r in repo_entries:
            if r['github_name']:
                st, _ = fetch_repo_runs(r['github_name'], oldest_start_date)
                if st != 200:
                    err_msg = f"HTTP {st}" if st else "network error"
                    problems.append(f"could not verify run list for {r['github_name']} ({err_msg})")

    for file_path, lines in files_data.items():
        in_red_runs_section = False
        red_run_claims_in_file = set()
        file_content = ''.join(lines)
        has_slice_metadata = ('Status:' in file_content or 'Start heads:' in file_content)

        for line_idx, line in enumerate(lines, 1):
            stripped = line.strip()

            if stripped.startswith('## '):
                in_red_runs_section = (stripped == '## Red runs on main')

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

                repo = find_repo_for_sha(sha)
                if not repo:
                    failed_commits.add(sha)
                    problems.append(f"{file_path}:{line_idx}: {hex_str} is not a commit in any given repo")

            # 2. Run id mentions and claims
            if has_any_github_name:
                valid_claim_spans = set()
                for m in claim_pattern.finditer(line):
                    valid_claim_spans.add(m.span())
                if in_red_runs_section:
                    for m in red_claim_pattern.finditer(line):
                        valid_claim_spans.add(m.span())

                mentions_in_line = []
                for m in mention_pattern.finditer(line):
                    mentions_in_line.append((m.start(), m.end(), m.group(1), m.group(0)))
                for m in sha_mention_pattern.finditer(line):
                    mentions_in_line.append((m.start(), m.end(), m.group(2), m.group(0)))

                seen_mention_spans = set()
                for start, end, run_id, full_match in mentions_in_line:
                    span_key = (start, end)
                    if span_key in seen_mention_spans:
                        continue
                    seen_mention_spans.add(span_key)

                    is_valid = any(c_start <= start and end <= c_end for c_start, c_end in valid_claim_spans)
                    if not is_valid:
                        if re.fullmatch(r'(?i)run\s+[0-9]{6,}', full_match.strip()):
                            has_sha_prefix = False
                            if start >= 41:
                                preceding = line[start - 41:start]
                                if preceding.endswith(' ') and re.fullmatch(r'[0-9a-fA-F]{40}', preceding[:40]):
                                    has_sha_prefix = True
                            if not has_sha_prefix:
                                problems.append(f"{file_path}:{line_idx}: run id without its head SHA")
                            else:
                                problems.append(f"{file_path}:{line_idx}: run {run_id}: run id not in \"<sha> run <id>\" form")
                        else:
                            problems.append(f"{file_path}:{line_idx}: run {run_id}: run id not in \"<sha> run <id>\" form")

            # 3. Standard run claims
            for match in claim_pattern.finditer(line):
                sha = match.group(1).lower()
                run_id = match.group(2)
                total_runs_checked += 1

                repo = find_repo_for_sha(sha)
                if not repo:
                    continue

                if not repo['github_name']:
                    problems.append(f"{file_path}:{line_idx}: no GitHub name for repo {repo['path']}")
                    continue

                owner_repo = repo['github_name']
                status_code, data_or_err = fetch_run(owner_repo, run_id)

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

            # 4. Red run claims in ## Red runs on main
            if in_red_runs_section:
                for match in red_claim_pattern.finditer(line):
                    sha = match.group(1).lower()
                    run_id = match.group(2)
                    red_run_claims_in_file.add(str(run_id))
                    total_red_runs_checked += 1

                    repo = find_repo_for_sha(sha)
                    if not repo:
                        continue

                    if not repo['github_name']:
                        problems.append(f"{file_path}:{line_idx}: no GitHub name for repo {repo['path']}")
                        continue

                    owner_repo = repo['github_name']
                    status_code, data_or_err = fetch_run(owner_repo, run_id)

                    if status_code == 404:
                        problems.append(f"{file_path}:{line_idx}: run {run_id}: not found")
                    elif status_code == 200 and isinstance(data_or_err, dict):
                        head_sha = str(data_or_err.get('head_sha', '')).lower()
                        conclusion = data_or_err.get('conclusion')
                        if head_sha != sha:
                            problems.append(f"{file_path}:{line_idx}: run {run_id}: head_sha is {head_sha}")
                        elif conclusion not in RED_CONCLUSIONS:
                            problems.append(f"{file_path}:{line_idx}: run {run_id}: is not red (conclusion {conclusion})")
                    else:
                        err_msg = f"HTTP {status_code}" if status_code else str(data_or_err)
                        problems.append(f"{file_path}:{line_idx}: run {run_id}: could not verify run {run_id} ({err_msg})")

        # 5. Slice range & undisclosed red runs check
        if has_slice_metadata and has_any_github_name:
            start_heads_line = None
            last_heads_line = None
            status_val = None

            for line in lines:
                if line.startswith('Status:'):
                    if 'IN PROGRESS' in line:
                        status_val = 'IN PROGRESS'
                    elif 'COMPLETE' in line:
                        status_val = 'COMPLETE'
                elif line.startswith('Start heads:'):
                    start_heads_line = line
                elif line.startswith('Last pushed heads'):
                    last_heads_line = line

            if not start_heads_line or not status_val:
                problems.append(f"{file_path}: cannot work out slice range")
            else:
                start_shas = [s.lower() for s in hex_pattern.findall(start_heads_line) if len(s) == 40]
                last_shas = [s.lower() for s in hex_pattern.findall(last_heads_line) if len(s) == 40] if last_heads_line else []

                # Verify Last pushed heads really were green
                if last_heads_line:
                    for l_idx, line in enumerate(lines, 1):
                        if line.startswith('Last pushed heads'):
                            for l_sha in last_shas:
                                l_repo = find_repo_for_sha(l_sha)
                                if not l_repo or not l_repo['github_name']:
                                    problems.append(f"{file_path}:{l_idx}: cannot work out slice range")
                                    continue
                                owner_repo = l_repo['github_name']
                                st, runs = fetch_repo_runs(owner_repo, oldest_start_date)
                                if st != 200 or runs is None:
                                    err_msg = f"HTTP {st}" if st else "network error"
                                    problems.append(f"{file_path}:{l_idx}: could not verify ({err_msg})")
                                else:
                                    has_green = any(
                                        str(r.get('head_sha', '')).lower() == l_sha and
                                        r.get('status') == 'completed' and
                                        r.get('conclusion') == 'success'
                                        for r in runs
                                    )
                                    if not has_green:
                                        problems.append(f"{file_path}:{l_idx}: last pushed head {l_sha} has no green run")

                # Match each start SHA to its repo
                repo_ranges = []
                for s_sha in start_shas:
                    r = find_repo_for_sha(s_sha)
                    if not r:
                        problems.append(f"{file_path}: cannot work out slice range")
                        continue

                    e_sha = None
                    if status_val == 'IN PROGRESS':
                        res = subprocess.run(['git', '-C', r['path'], 'rev-parse', 'HEAD'],
                                             capture_output=True, text=True)
                        if res.returncode == 0 and res.stdout.strip():
                            e_sha = res.stdout.strip().lower()
                    else: # COMPLETE
                        # If this repo is the one containing file_path
                        # Check git log -S'Status: COMPLETE' on file_path inside r['path']
                        rel_file = os.path.relpath(file_path, r['path'])
                        if not rel_file.startswith('..') and os.path.exists(os.path.join(r['path'], rel_file)):
                            res = subprocess.run(
                                ['git', '-C', r['path'], 'log', '--reverse', "-SStatus: COMPLETE", '--format=%H', '--', rel_file],
                                capture_output=True, text=True
                            )
                            c_lines = [cl.strip().lower() for cl in res.stdout.splitlines() if cl.strip()]
                            if c_lines:
                                e_sha = c_lines[0]

                        if not e_sha:
                            # Match from Last pushed heads in r
                            for cand in last_shas:
                                if is_commit_in_repo(r['path'], cand):
                                    e_sha = cand
                                    break

                    if not e_sha or not is_commit_in_repo(r['path'], e_sha):
                        problems.append(f"{file_path}: cannot work out slice range")
                        continue

                    repo_ranges.append((r, s_sha, e_sha))

                for r, s_sha, e_sha in repo_ranges:
                    total_ranges_checked += 1
                    rev_res = subprocess.run(
                        ['git', '-C', r['path'], 'rev-list', f'{s_sha}..{e_sha}'],
                        capture_output=True, text=True
                    )
                    if rev_res.returncode != 0:
                        problems.append(f"{file_path}: cannot work out slice range")
                        continue

                    slice_commits = set(c.strip().lower() for c in rev_res.stdout.splitlines() if c.strip())

                    if r['github_name']:
                        owner_repo = r['github_name']
                        st, runs = fetch_repo_runs(owner_repo, oldest_start_date)
                        if st != 200 or runs is None:
                            err_msg = f"HTTP {st}" if st else "network error"
                            problems.append(f"{file_path}: could not verify ({err_msg})")
                        else:
                            for run in runs:
                                h_sha = str(run.get('head_sha', '')).lower()
                                if h_sha in slice_commits:
                                    status = run.get('status')
                                    conc = run.get('conclusion')
                                    if status == 'completed' and conc in RED_CONCLUSIONS:
                                        r_id = str(run.get('id', ''))
                                        if r_id not in red_run_claims_in_file:
                                            r_num = run.get('run_number', '?')
                                            problems.append(
                                                f"{file_path}: undisclosed red run {r_id} (run number {r_num}) on {h_sha} in {owner_repo}"
                                            )

        # 6. Fix checklist verification
        fix_ids_line = None
        has_fix_checklist_section = False
        checklist_lines = []
        in_fix_checklist_section = False

        for line_idx, line in enumerate(lines, 1):
            stripped = line.strip()
            if line.startswith('Fix ids:'):
                fix_ids_line = (line_idx, line)
            if stripped.startswith('## '):
                if stripped == '## Fix checklist':
                    has_fix_checklist_section = True
                    in_fix_checklist_section = True
                else:
                    in_fix_checklist_section = False
            elif in_fix_checklist_section:
                checklist_lines.append((line_idx, line))

        is_frozen = os.path.basename(file_path) in {'cleanup_slice_10_progress.md'}

        if has_fix_checklist_section and not fix_ids_line and not is_frozen:
            problems.append(f"{file_path}: '## Fix checklist' section present but no 'Fix ids:' line")
        elif fix_ids_line:
            total_fix_checklists_checked += 1
            raw_ids = fix_ids_line[1][len('Fix ids:'):].strip().split()
            expected_ids = raw_ids
            total_fix_ids_checked += len(expected_ids)

            if len(expected_ids) != len(set(expected_ids)):
                for eid in expected_ids:
                    if expected_ids.count(eid) > 1:
                        problems.append(f"{file_path}:{fix_ids_line[0]}: duplicate Fix id '{eid}' in 'Fix ids:' line")
                        break

            if not has_fix_checklist_section:
                problems.append(f"{file_path}: 'Fix ids:' line present but no '## Fix checklist' section")
            else:
                seen_ids = set()
                for l_idx, raw_line in checklist_lines:
                    s = raw_line.strip()
                    if not s:
                        continue
                    m = re.match(r'^Fix\s+(\S+)\s+(done|not done):\s*(.*)$', s)
                    if not m or not m.group(3).strip():
                        problems.append(f"{file_path}:{l_idx}: malformed Fix checklist line '{s}'")
                        continue
                    fix_id = m.group(1)
                    if fix_id not in expected_ids:
                        problems.append(f"{file_path}:{l_idx}: Fix id '{fix_id}' in checklist is not expected")
                    elif fix_id in seen_ids:
                        problems.append(f"{file_path}:{l_idx}: duplicate Fix id '{fix_id}' in checklist")
                    else:
                        seen_ids.add(fix_id)

                file_status = None
                for line in lines:
                    if line.startswith('Status:'):
                        if 'IN PROGRESS' in line:
                            file_status = 'IN PROGRESS'
                        elif 'COMPLETE' in line:
                            file_status = 'COMPLETE'
                        break

                if file_status == 'COMPLETE':
                    for exp_id in expected_ids:
                        if exp_id not in seen_ids:
                            problems.append(f"{file_path}: missing Fix id '{exp_id}' in checklist")

    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        print(f"Checked {total_fix_checklists_checked} Fix checklist(s), {total_fix_ids_checked} Fix id(s).", file=sys.stderr)
        print(f"Checked {total_files_checked} file(s), {total_shas_checked} SHA(s), {total_runs_checked} run id(s) checked, {total_red_runs_checked} red run(s) checked, and {total_ranges_checked} slice range(s) checked. Found {len(problems)} problem(s).", file=sys.stderr)
        sys.exit(1)

    print(f"Checked {total_fix_checklists_checked} Fix checklist(s), {total_fix_ids_checked} Fix id(s).")
    print(f"Checked {total_files_checked} file(s), {total_shas_checked} SHA(s), {total_runs_checked} run id(s) checked, {total_red_runs_checked} red run(s) checked, and {total_ranges_checked} slice range(s) checked. All SHAs are valid commits.")
    sys.exit(0)


if __name__ == '__main__':
    main()
