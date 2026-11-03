#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_notes_shas.py"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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

echo "All notes SHA check self-tests passed (NS1 - NS7)."
