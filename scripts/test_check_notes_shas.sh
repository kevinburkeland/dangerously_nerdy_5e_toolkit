#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_notes_shas.py"

TMP_DIR=$(mktemp -d)
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

setup_repo() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -b main >/dev/null 2>&1
  git config user.name "Test Runner"
  git config user.email "test@example.com"
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null
}

# NS1: a notes file holding a real commit SHA of the given repo passes.
(
  repo="$TMP_DIR/repo_ns1"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns1.md"
  echo "Commit: $sha" > "$notes"

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes")
  if [[ "$out" != *"All SHAs are valid commits"* ]]; then
    echo "FAIL: NS1 expected pass for valid commit SHA, got: $out" >&2
    exit 1
  fi
)

# NS2: the same file with the last 33 characters of that SHA replaced by other hex digits fails, naming the file, the line and the SHA.
(
  repo="$TMP_DIR/repo_ns2"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)
  fake_sha="${sha:0:7}000000000000000000000000000000000"

  notes="$TMP_DIR/notes_ns2.md"
  echo "Commit: $fake_sha" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS2 expected failure for fake SHA, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"$notes:1:"* ]] || [[ "$out" != *"$fake_sha"* ]]; then
    echo "FAIL: NS2 expected failure output to name file, line 1, and SHA, got: $out" >&2
    exit 1
  fi
)

# NS3: a SHA that exists only in a second repo passes when both repos are given with --repo, and fails when only the first is given.
(
  repo1="$TMP_DIR/repo_ns3_1"
  repo2="$TMP_DIR/repo_ns3_2"
  setup_repo "$repo1"
  setup_repo "$repo2"

  echo "unique in repo2" > "$repo2/unique.txt"
  git -C "$repo2" add unique.txt
  git -C "$repo2" commit -m "commit unique to repo 2" >/dev/null
  sha2=$(git -C "$repo2" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns3.md"
  echo "Ref: $sha2" > "$notes"

  # With only repo1: must fail
  set +e
  out1=$(python3 -I "$CHECK_SCRIPT" --repo "$repo1" "$notes" 2>&1)
  rc1=$?
  set -e
  if [ "$rc1" -eq 0 ]; then
    echo "FAIL: NS3 expected failure when SHA only in repo2 is checked against repo1" >&2
    exit 1
  fi

  # With both repo1 and repo2: must pass
  set +e
  out2=$(python3 -I "$CHECK_SCRIPT" --repo "$repo1" --repo "$repo2" "$notes" 2>&1)
  rc2=$?
  set -e
  if [ "$rc2" -ne 0 ]; then
    echo "FAIL: NS3 expected pass when both repos are given, got rc $rc2: $out2" >&2
    exit 1
  fi
)

# NS4: a 41-character hex run fails.
(
  repo="$TMP_DIR/repo_ns4"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)
  long_sha="${sha}a"

  notes="$TMP_DIR/notes_ns4.md"
  echo "Long: $long_sha" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS4 expected failure for 41-character SHA" >&2
    exit 1
  fi
  if [[ "$out" != *"is longer than 40 characters"* ]]; then
    echo "FAIL: NS4 expected output to state longer than 40 characters, got: $out" >&2
    exit 1
  fi
)

# NS5: a line holding run 40761057967 and a 39-character hex run passes.
(
  repo="$TMP_DIR/repo_ns5"
  setup_repo "$repo"
  notes="$TMP_DIR/notes_ns5.md"
  echo "run 40761057967 and 1234567890abcdef1234567890abcdef1234567" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: NS5 expected pass for <40 character hex runs and run ids, got rc $rc: $out" >&2
    exit 1
  fi
)

# NS6: a --repo path that isn't a git repository exits non-zero.
(
  not_a_repo="$TMP_DIR/not_a_repo"
  mkdir -p "$not_a_repo"
  notes="$TMP_DIR/notes_ns6.md"
  echo "empty notes" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$not_a_repo" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS6 expected failure when --repo is not a git repository" >&2
    exit 1
  fi
)

# NS7: a real tree SHA (not a commit) fails.
(
  repo="$TMP_DIR/repo_ns7"
  setup_repo "$repo"
  tree_sha=$(git -C "$repo" rev-parse HEAD^{tree})

  notes="$TMP_DIR/notes_ns7.md"
  echo "Tree SHA: $tree_sha" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS7 expected failure for tree SHA (must be commit), got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"is not a commit in any given repo"* ]]; then
    echo "FAIL: NS7 expected output to state is not a commit, got: $out" >&2
    exit 1
  fi
)

# Start local fixture server for NS8-NS13
SERVER_DIR="$TMP_DIR/server"
mkdir -p "$SERVER_DIR/repos/test-org/test-repo/actions/runs"
PORT_FILE="$TMP_DIR/server.port"

(
  cd "$SERVER_DIR"
  python3 -c "
import http.server, socketserver, os, urllib.parse

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if os.path.exists('server.status'):
            try:
                with open('server.status') as sf:
                    code = int(sf.read().strip())
                self.send_response(code)
                self.end_headers()
                self.wfile.write(b'Error triggered')
                return
            except Exception:
                pass

        if path.endswith('/actions/runs'):
            rel_file = path.strip('/') + '.list.json'
            if os.path.exists(rel_file):
                with open(rel_file, 'rb') as lf:
                    data = lf.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            else:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', '21')
                self.end_headers()
                self.wfile.write(b'{\"workflow_runs\": []}')
                return
        return super().do_GET()

with socketserver.TCPServer(('127.0.0.1', 0), Handler) as httpd:
    port = httpd.server_address[1]
    with open('$PORT_FILE', 'w') as f:
        f.write(str(port))
    httpd.serve_forever()
"
) &
SERVER_PID=$!

while [ ! -s "$PORT_FILE" ]; do
  sleep 0.05
done
SERVER_PORT=$(cat "$PORT_FILE")
API_BASE="http://127.0.0.1:$SERVER_PORT"

# NS8 (control): a notes line <real sha> run 111 where fixture 111 has that head_sha and success passes, and summary says 1 run id checked.
(
  repo="$TMP_DIR/repo_ns8"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  echo "{\"head_sha\": \"$sha\", \"conclusion\": \"success\"}" > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/111"
  notes="$TMP_DIR/notes_ns8.md"
  echo "Step 1: $sha run 111" > "$notes"

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  if [[ "$out" != *"1 run id(s) checked"* ]] || [[ "$out" != *"All SHAs are valid commits"* ]]; then
    echo "FAIL: NS8 expected pass with 1 run id checked, got: $out" >&2
    exit 1
  fi
)

# NS9: run 222 with no fixture file (404) fails, naming file, line and 222.
(
  repo="$TMP_DIR/repo_ns9"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns9.md"
  echo "Step 2: $sha run 222" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS9 expected failure for 404 run id, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"$notes:1:"* ]] || [[ "$out" != *"222"* ]] || [[ "$out" != *"not found"* ]]; then
    echo "FAIL: NS9 expected failure output to name file, line 1, 222, and not found, got: $out" >&2
    exit 1
  fi
)

# NS10: fixture head_sha is a different SHA: fails, head_sha is …
(
  repo="$TMP_DIR/repo_ns10"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  echo "{\"head_sha\": \"0000000000000000000000000000000000000000\", \"conclusion\": \"success\"}" > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/333"
  notes="$TMP_DIR/notes_ns10.md"
  echo "Step 3: $sha run 333" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS10 expected failure for head_sha mismatch, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"head_sha is"* ]]; then
    echo "FAIL: NS10 expected output to state 'head_sha is', got: $out" >&2
    exit 1
  fi
)

# NS11: fixture conclusion failure: fails, conclusion is failure.
(
  repo="$TMP_DIR/repo_ns11"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  echo "{\"head_sha\": \"$sha\", \"conclusion\": \"failure\"}" > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/444"
  notes="$TMP_DIR/notes_ns11.md"
  echo "Step 4: $sha run 444" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS11 expected failure for non-success conclusion, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"conclusion is failure"* ]]; then
    echo "FAIL: NS11 expected output to state 'conclusion is failure', got: $out" >&2
    exit 1
  fi
)

# NS12: run 3333333 with no SHA before it fails, run id without its head SHA.
(
  repo="$TMP_DIR/repo_ns12"
  setup_repo "$repo"

  notes="$TMP_DIR/notes_ns12.md"
  echo "Orphan run 3333333 without SHA" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS12 expected failure for run id without its head SHA, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"run id without its head SHA"* ]]; then
    echo "FAIL: NS12 expected output to state 'run id without its head SHA', got: $out" >&2
    exit 1
  fi
)

# NS13: the server is stopped (or --api-base points at a closed port): fails, could not verify.
(
  repo="$TMP_DIR/repo_ns13"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns13.md"
  echo "Step 5: $sha run 111" > "$notes"

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "http://127.0.0.1:65534" "$notes" 2>&1)
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: NS13 expected failure when server is unreachable, got exit 0" >&2
    exit 1
  fi
  if [[ "$out" != *"could not verify"* ]]; then
    echo "FAIL: NS13 expected output to state 'could not verify', got: $out" >&2
    exit 1
  fi
)

# NS14: <real sha> run #111 fails run id not in "<sha> run <id>" form; so do run: 111111 and actions/runs/111111.
(
  repo="$TMP_DIR/repo_ns14"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  notes1="$TMP_DIR/notes_ns14_1.md"
  echo "Step: $sha run #111" > "$notes1"
  set +e
  out1=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes1" 2>&1)
  rc1=$?
  set -e
  [ "$rc1" -ne 0 ] || { echo "FAIL: NS14 expected failure for run #111"; exit 1; }
  [[ "$out1" == *'run id not in "<sha> run <id>" form'* ]] || { echo "FAIL: NS14 expected run id not in form message, got: $out1"; exit 1; }

  notes2="$TMP_DIR/notes_ns14_2.md"
  echo "Step: run: 111111" > "$notes2"
  set +e
  out2=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes2" 2>&1)
  rc2=$?
  set -e
  [ "$rc2" -ne 0 ] || { echo "FAIL: NS14 expected failure for run: 111111"; exit 1; }
  [[ "$out2" == *'run id not in "<sha> run <id>" form'* ]] || { echo "FAIL: NS14 expected run id not in form message, got: $out2"; exit 1; }

  notes3="$TMP_DIR/notes_ns14_3.md"
  echo "Step: actions/runs/111111" > "$notes3"
  set +e
  out3=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes3" 2>&1)
  rc3=$?
  set -e
  [ "$rc3" -ne 0 ] || { echo "FAIL: NS14 expected failure for actions/runs/111111"; exit 1; }
  [[ "$out3" == *'run id not in "<sha> run <id>" form'* ]] || { echo "FAIL: NS14 expected run id not in form message, got: $out3"; exit 1; }
)

# NS15 (control): runs 583 and 584 (short numbers), the word rerun before a 6-digit number, and a correct red-run line are not flagged by rule 1.
(
  repo="$TMP_DIR/repo_ns15"
  setup_repo "$repo"
  sha=$(git -C "$repo" rev-parse HEAD)

  echo '{"head_sha": "'"$sha"'", "conclusion": "failure"}' > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/600001"
  notes="$TMP_DIR/notes_ns15.md"
  cat << EOF > "$notes"
Here we mention runs 583 and 584 and rerun 123456.

## Red runs on main
$sha red run 600001
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  [[ "$out" == *"1 red run(s) checked"* ]] || { echo "FAIL: NS15 expected pass with 1 red run checked, got: $out"; exit 1; }
)

# NS16 (control): a fixture repo with commits A (start), B, C (head), notes IN PROGRESS starting at A, a fixture run list holding a failure run on B and success runs on B's fix C; the notes list B's red run. Passes, summary says 1 red run checked.
(
  repo="$TMP_DIR/repo_ns16"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  echo "b" > "$repo/b.txt" && git -C "$repo" add b.txt && git -C "$repo" commit -m "commit B" >/dev/null
  sha_B=$(git -C "$repo" rev-parse HEAD)

  echo "c" > "$repo/c.txt" && git -C "$repo" add c.txt && git -C "$repo" commit -m "commit C" >/dev/null
  sha_C=$(git -C "$repo" rev-parse HEAD)

  cat << EOF > "$SERVER_DIR/repos/test-org/test-repo/actions/runs.list.json"
{"workflow_runs": [
  {"id": 601, "head_sha": "$sha_B", "status": "completed", "conclusion": "failure", "run_number": 601},
  {"id": 602, "head_sha": "$sha_C", "status": "completed", "conclusion": "success", "run_number": 602}
]}
EOF
  echo '{"head_sha": "'"$sha_B"'", "conclusion": "failure"}' > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/601"
  echo '{"head_sha": "'"$sha_C"'", "conclusion": "success"}' > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/602"

  notes="$TMP_DIR/notes_ns16.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Red runs on main
$sha_B red run 601
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  [[ "$out" == *"1 red run(s) checked"* ]] || { echo "FAIL: NS16 expected 1 red run checked, got: $out"; exit 1; }
)

# NS17: the same without the red-run line fails undisclosed red run.
(
  repo="$TMP_DIR/repo_ns16"
  sha_A=$(git -C "$repo" rev-parse HEAD~2)

  notes="$TMP_DIR/notes_ns17.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Red runs on main
None
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS17 expected failure for undisclosed red run"; exit 1; }
  [[ "$out" == *"undisclosed red run"* ]] || { echo "FAIL: NS17 expected undisclosed red run message, got: $out"; exit 1; }
)

# NS18: a red-run line whose fixture run is success fails is not red.
(
  repo="$TMP_DIR/repo_ns16"
  sha_C=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns18.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_C

## Red runs on main
$sha_C red run 602
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS18 expected failure for success run in red runs section"; exit 1; }
  [[ "$out" == *"is not red"* ]] || { echo "FAIL: NS18 expected 'is not red' message, got: $out"; exit 1; }
)

# NS19: a failure run on a commit before the start head needs no line (passes).
(
  repo="$TMP_DIR/repo_ns19"
  setup_repo "$repo"
  sha_Z=$(git -C "$repo" rev-parse HEAD)

  echo "a" > "$repo/a.txt" && git -C "$repo" add a.txt && git -C "$repo" commit -m "commit A" >/dev/null
  sha_A=$(git -C "$repo" rev-parse HEAD)

  echo "b" > "$repo/b.txt" && git -C "$repo" add b.txt && git -C "$repo" commit -m "commit B" >/dev/null
  sha_B=$(git -C "$repo" rev-parse HEAD)

  cat << EOF > "$SERVER_DIR/repos/test-org/test-repo/actions/runs.list.json"
{"workflow_runs": [
  {"id": 801, "head_sha": "$sha_Z", "status": "completed", "conclusion": "failure", "run_number": 801},
  {"id": 802, "head_sha": "$sha_B", "status": "completed", "conclusion": "success", "run_number": 802}
]}
EOF

  notes="$TMP_DIR/notes_ns19.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Red runs on main
None
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  [[ "$out" == *"All SHAs are valid commits"* ]] || { echo "FAIL: NS19 expected pass, got: $out"; exit 1; }
)

# NS20: notes COMPLETE, with a red run on a commit after the commit that set COMPLETE: no line needed for this file (passes).
(
  repo="$TMP_DIR/repo_ns20"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  notes="$repo/cleanup_test_progress.md"
  cat << EOF > "$notes"
# Progress
Status: COMPLETE
Start heads: test-repo $sha_A
Last pushed heads (CI green): test-repo $sha_A

## Red runs on main
None
EOF
  git -C "$repo" add cleanup_test_progress.md
  git -C "$repo" commit -m "Status: COMPLETE" >/dev/null
  sha_B=$(git -C "$repo" rev-parse HEAD)

  echo "c" > "$repo/c.txt" && git -C "$repo" add c.txt && git -C "$repo" commit -m "commit C after complete" >/dev/null
  sha_C=$(git -C "$repo" rev-parse HEAD)

  cat << EOF > "$SERVER_DIR/repos/test-org/test-repo/actions/runs.list.json"
{"workflow_runs": [
  {"id": 901, "head_sha": "$sha_A", "status": "completed", "conclusion": "success", "run_number": 901},
  {"id": 902, "head_sha": "$sha_C", "status": "completed", "conclusion": "failure", "run_number": 902}
]}
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  [[ "$out" == *"All SHAs are valid commits"* ]] || { echo "FAIL: NS20 expected pass, got: $out"; exit 1; }
)

# NS21: a Last pushed heads SHA whose only run is failure fails has no green run.
(
  repo="$TMP_DIR/repo_ns21"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  echo "b" > "$repo/b.txt" && git -C "$repo" add b.txt && git -C "$repo" commit -m "commit B" >/dev/null
  sha_B=$(git -C "$repo" rev-parse HEAD)

  cat << EOF > "$SERVER_DIR/repos/test-org/test-repo/actions/runs.list.json"
{"workflow_runs": [
  {"id": 950, "head_sha": "$sha_B", "status": "completed", "conclusion": "failure", "run_number": 950}
]}
EOF

  notes="$TMP_DIR/notes_ns21.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A
Last pushed heads (CI green): test-repo $sha_B

## Red runs on main
None
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS21 expected failure for ungreen last pushed head"; exit 1; }
  [[ "$out" == *"has no green run"* ]] || { echo "FAIL: NS21 expected 'has no green run' message, got: $out"; exit 1; }
)

# NS22: the run-list request returns 500: fails could not verify.
(
  repo="$TMP_DIR/repo_ns21"
  notes="$TMP_DIR/notes_ns21.md"

  echo "500" > "$SERVER_DIR/server.status"
  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  rm -f "$SERVER_DIR/server.status"
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS22 expected failure on HTTP 500"; exit 1; }
  [[ "$out" == *"could not verify"* ]] || { echo "FAIL: NS22 expected 'could not verify' message, got: $out"; exit 1; }
)

# NS23: a complete, correct checklist passes.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns23.md"
  cat << EOF > "$notes"
# Progress
Status: COMPLETE
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1 2.2

## Mutation branches
None

## Fix checklist
Fix 2.1 done: completed first fix
Fix 2.2 not done: postponed to next slice
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes")
  if [[ "$out" != *"Checked 1 Fix checklist(s), 2 Fix id(s)."* ]]; then
    echo "FAIL: NS23 expected checklist summary, got: $out" >&2
    exit 1
  fi
)

# NS24: a missing id with Status: COMPLETE fails naming the id.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns24.md"
  cat << EOF > "$notes"
# Progress
Status: COMPLETE
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1 2.2

## Mutation branches
None

## Fix checklist
Fix 2.1 done: completed first fix
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS24 expected failure on missing id with COMPLETE"; exit 1; }
  [[ "$out" == *"missing Fix id '2.2'"* ]] || { echo "FAIL: NS24 expected 'missing Fix id '2.2'' message, got: $out"; exit 1; }
)

# NS25: the same missing id with Status: IN PROGRESS passes.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns25.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1 2.2

## Fix checklist
Fix 2.1 done: completed first fix
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes")
  if [[ "$out" != *"All SHAs are valid commits"* ]]; then
    echo "FAIL: NS25 expected pass for missing id when IN PROGRESS, got: $out" >&2
    exit 1
  fi
)

# NS26: an extra id fails naming the id.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns26.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1

## Fix checklist
Fix 2.1 done: completed first fix
Fix 2.2 done: extra fix
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS26 expected failure on extra id"; exit 1; }
  [[ "$out" == *"Fix id '2.2' in checklist is not expected"* ]] || { echo "FAIL: NS26 expected extra id message, got: $out"; exit 1; }
)

# NS27: a duplicate id fails naming the id.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns27.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1

## Fix checklist
Fix 2.1 done: completed first fix
Fix 2.1 done: duplicate fix
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS27 expected failure on duplicate id"; exit 1; }
  [[ "$out" == *"duplicate Fix id '2.1'"* ]] || { echo "FAIL: NS27 expected duplicate id message, got: $out"; exit 1; }
)

# NS28: a renumbered list (the checklist says Fix 3.5 where the header says 3.6) fails.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns28.md"
  cat << EOF > "$notes"
# Progress
Status: COMPLETE
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 3.6

## Mutation branches
None

## Fix checklist
Fix 3.5 done: renumbered fix
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS28 expected failure on renumbered list"; exit 1; }
  [[ "$out" == *"Fix id '3.5' in checklist is not expected"* ]] || { echo "FAIL: NS28 expected not expected message, got: $out"; exit 1; }
)

# NS29: a malformed line (Fix 2.1: did it) fails.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns29.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha
Fix ids: 2.1

## Fix checklist
Fix 2.1: did it
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS29 expected failure on malformed line"; exit 1; }
  [[ "$out" == *"malformed Fix checklist line"* ]] || { echo "FAIL: NS29 expected malformed line message, got: $out"; exit 1; }
)

# NS30: a checklist with no Fix ids: line fails.
(
  repo="$TMP_DIR/repo_ns1"
  sha=$(git -C "$repo" rev-parse HEAD)
  notes="$TMP_DIR/notes_ns30.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha
Last pushed heads (CI green): test-repo $sha

## Fix checklist
Fix 2.1 done: fix done
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS30 expected failure for checklist without Fix ids:"; exit 1; }
  [[ "$out" == *"no 'Fix ids:' line"* ]] || { echo "FAIL: NS30 expected 'no Fix ids: line' message, got: $out"; exit 1; }
)

# NS31: the frozen file's real text passes.
(
  core_repo=""
  ruleset_repo=""
  if [ -d "$SCRIPT_DIR/../../vtt-engine-core" ]; then
    core_repo="$SCRIPT_DIR/../../vtt-engine-core"
  elif [ -n "${RUNNER_TEMP:-}" ] && [ -d "$RUNNER_TEMP/core.git" ]; then
    core_repo="$RUNNER_TEMP/core.git"
  else
    git clone --bare --filter=blob:none https://github.com/kevinburkeland/vtt-engine-core.git "$TMP_DIR/core_ns31.git" >/dev/null 2>&1
    core_repo="$TMP_DIR/core_ns31.git"
  fi

  if [ -d "$SCRIPT_DIR/../../vtt-ruleset-dnd5e" ]; then
    ruleset_repo="$SCRIPT_DIR/../../vtt-ruleset-dnd5e"
  elif [ -n "${RUNNER_TEMP:-}" ] && [ -d "$RUNNER_TEMP/ruleset.git" ]; then
    ruleset_repo="$RUNNER_TEMP/ruleset.git"
  else
    git clone --bare --filter=blob:none https://github.com/kevinburkeland/vtt-ruleset-dnd5e.git "$TMP_DIR/ruleset_ns31.git" >/dev/null 2>&1
    ruleset_repo="$TMP_DIR/ruleset_ns31.git"
  fi

  frozen_notes="$TMP_DIR/cleanup_slice_10_progress.md"
  cp "$SCRIPT_DIR/../notes/cleanup_slice_10_progress.md" "$frozen_notes"

  out=$(python3 -I "$CHECK_SCRIPT" \
    --repo .=kevinburkeland/dangerously_nerdy_5e_toolkit \
    --repo "$core_repo=kevinburkeland/vtt-engine-core" \
    --repo "$ruleset_repo=kevinburkeland/vtt-ruleset-dnd5e" \
    "$frozen_notes")
  if [[ "$out" != *"All SHAs are valid commits"* ]]; then
    echo "FAIL: NS31 expected frozen notes file to pass, got: $out" >&2
    exit 1
  fi
)

# NS32: a correct mutation branch line passes
(
  repo="$TMP_DIR/repo_ns32"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)
  echo "mut1" > "$repo/mut1.txt" && git -C "$repo" add mut1.txt && git -C "$repo" commit -s -m "MUTATION — do not merge: T1" >/dev/null
  sha_mut=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns32.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Mutation branches
mutation/bs11-t1 $sha_mut
EOF

  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes")
  [[ "$out" == *"All SHAs are valid commits"* ]] || { echo "FAIL: NS32 expected pass, got: $out"; exit 1; }
)

# NS33: a wrong subject fails
(
  repo="$TMP_DIR/repo_ns33"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)
  echo "mut2" > "$repo/mut2.txt" && git -C "$repo" add mut2.txt && git -C "$repo" commit -s -m "Wrong subject commit" >/dev/null
  sha_mut=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns33.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Mutation branches
mutation/bs11-t1 $sha_mut
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS33 expected failure for wrong subject"; exit 1; }
  [[ "$out" == *"does not start with 'MUTATION — do not merge: T1'"* ]] || { echo "FAIL: NS33 output: $out"; exit 1; }
)

# NS34: a malformed line fails
(
  repo="$TMP_DIR/repo_ns34"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns34.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Mutation branches
not-a-valid-mutation-line
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS34 expected failure for malformed line"; exit 1; }
  [[ "$out" == *"malformed mutation branch line"* ]] || { echo "FAIL: NS34 output: $out"; exit 1; }
)

# NS35: a SHA that exists nowhere fails
(
  repo="$TMP_DIR/repo_ns35"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns35.md"
  cat << EOF > "$notes"
# Progress
Status: IN PROGRESS
Start heads: test-repo $sha_A

## Mutation branches
mutation/bs11-t1 0123456789abcdef0123456789abcdef01234567
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS35 expected failure for non-existent commit"; exit 1; }
  [[ "$out" == *"mutation commit 0123456789abcdef0123456789abcdef01234567 is not in any given repo"* ]] || { echo "FAIL: NS35 output: $out"; exit 1; }
)

# NS36: COMPLETE without the section fails
(
  repo="$TMP_DIR/repo_ns36"
  setup_repo "$repo"
  sha_A=$(git -C "$repo" rev-parse HEAD)

  notes="$TMP_DIR/notes_ns36.md"
  cat << EOF > "$notes"
# Progress
Status: COMPLETE
Start heads: test-repo $sha_A
Last pushed heads: test-repo $sha_A
Fix ids: 1.1

## Steps
- [x] Step 1: test-repo $sha_A run 101

## Fix checklist
Fix 1.1 done: something
EOF
  echo '{"head_sha": "'"$sha_A"'", "conclusion": "success"}' > "$SERVER_DIR/repos/test-org/test-repo/actions/runs/101"
  cat << EOF > "$SERVER_DIR/repos/test-org/test-repo/actions/runs.list.json"
{"workflow_runs": [
  {"id": 101, "head_sha": "$sha_A", "status": "completed", "conclusion": "success", "run_number": 101}
]}
EOF

  set +e
  out=$(python3 -I "$CHECK_SCRIPT" --repo "$repo=test-org/test-repo" --api-base "$API_BASE" "$notes" 2>&1)
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: NS36 expected failure for COMPLETE without Mutation branches section"; exit 1; }
  [[ "$out" == *"requires '## Mutation branches' section"* ]] || { echo "FAIL: NS36 output: $out"; exit 1; }
)

# NS37: the real Cleanup slice 10.1 and Bonus slice 1 notes still pass.
(
  core_repo=""
  ruleset_repo=""
  if [ -d "$SCRIPT_DIR/../../vtt-engine-core" ]; then
    core_repo="$SCRIPT_DIR/../../vtt-engine-core"
  elif [ -n "${RUNNER_TEMP:-}" ] && [ -d "$RUNNER_TEMP/core.git" ]; then
    core_repo="$RUNNER_TEMP/core.git"
  else
    git clone --bare --filter=blob:none https://github.com/kevinburkeland/vtt-engine-core.git "$TMP_DIR/core_ns37.git" >/dev/null 2>&1
    core_repo="$TMP_DIR/core_ns37.git"
  fi

  if [ -d "$SCRIPT_DIR/../../vtt-ruleset-dnd5e" ]; then
    ruleset_repo="$SCRIPT_DIR/../../vtt-ruleset-dnd5e"
  elif [ -n "${RUNNER_TEMP:-}" ] && [ -d "$RUNNER_TEMP/ruleset.git" ]; then
    ruleset_repo="$RUNNER_TEMP/ruleset.git"
  else
    git clone --bare --filter=blob:none https://github.com/kevinburkeland/vtt-ruleset-dnd5e.git "$TMP_DIR/ruleset_ns37.git" >/dev/null 2>&1
    ruleset_repo="$TMP_DIR/ruleset_ns37.git"
  fi

  out=$(python3 -I "$CHECK_SCRIPT" \
    --repo .=kevinburkeland/dangerously_nerdy_5e_toolkit \
    --repo "$core_repo=kevinburkeland/vtt-engine-core" \
    --repo "$ruleset_repo=kevinburkeland/vtt-ruleset-dnd5e" \
    "$SCRIPT_DIR/../notes/cleanup_slice_10_1_progress.md" \
    "$SCRIPT_DIR/../notes/bonus_slice_1_progress.md")
  if [[ "$out" != *"All SHAs are valid commits"* ]]; then
    echo "FAIL: NS37 expected real notes to pass, got: $out" >&2
    exit 1
  fi
)

echo "All notes SHA check self-tests passed (NS1 - NS37)."
