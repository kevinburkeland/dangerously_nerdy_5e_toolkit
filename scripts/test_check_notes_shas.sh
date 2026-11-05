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
import http.server, socketserver

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

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

echo "All notes SHA check self-tests passed (NS1 - NS13)."
