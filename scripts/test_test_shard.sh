#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SHARD_PY="$SCRIPT_DIR/test_shard.py"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Setup test tree for SH1, SH2, SH3
setup_sh1_tree() {
  local base="$1"
  mkdir -p "$base/test/a" "$base/test/b" "$base/scripts"
  cp "$TEST_SHARD_PY" "$base/scripts/test_shard.py"
  chmod +x "$base/scripts/test_shard.py"

  for i in 00 01 02 03 04 05 06 07 08 09; do
    touch "$base/test/a/f${i}_test.dart"
  done
  touch "$base/test/b/z_test.dart"
}

# -----------------------------------------------------------------------------
# SH1 (control): 11 test files. list 0 4 and list 3 4
# -----------------------------------------------------------------------------
env1="$TMP_DIR/sh1"
setup_sh1_tree "$env1"

expected_0_4="test/a/f00_test.dart
test/a/f04_test.dart
test/a/f08_test.dart"

actual_0_4=$(cd "$env1" && python3 -I scripts/test_shard.py list 0 4)
if [ "$actual_0_4" != "$expected_0_4" ]; then
  echo "FAIL SH1: list 0 4 mismatch."
  echo "Expected:"
  echo "$expected_0_4"
  echo "Actual:"
  echo "$actual_0_4"
  exit 1
fi

expected_3_4="test/a/f03_test.dart
test/a/f07_test.dart"

actual_3_4=$(cd "$env1" && python3 -I scripts/test_shard.py list 3 4)
if [ "$actual_3_4" != "$expected_3_4" ]; then
  echo "FAIL SH1: list 3 4 mismatch."
  echo "Expected:"
  echo "$expected_3_4"
  echo "Actual:"
  echo "$actual_3_4"
  exit 1
fi
echo "PASS SH1"

# -----------------------------------------------------------------------------
# SH2: check 4 on same tree passes, shard counts add up to 11
# -----------------------------------------------------------------------------
check_out=$(cd "$env1" && python3 -I scripts/test_shard.py check 4)
sum_counts=0
while IFS= read -r line; do
  if [[ "$line" =~ ^shard\ [0-9]+:\ ([0-9]+)\ files$ ]]; then
    cnt="${BASH_REMATCH[1]}"
    sum_counts=$((sum_counts + cnt))
  fi
done <<< "$check_out"

if [ "$sum_counts" -ne 11 ]; then
  echo "FAIL SH2: shard counts sum is $sum_counts, expected 11"
  exit 1
fi
if [[ "$check_out" != *"total: 11 files in 4 shards"* ]]; then
  echo "FAIL SH2: total line mismatch in output: $check_out"
  exit 1
fi
echo "PASS SH2"

# -----------------------------------------------------------------------------
# SH3: non-test files are not listed
# -----------------------------------------------------------------------------
touch "$env1/test/a/helper.dart"
touch "$env1/test/a/notes_test.dart.txt"
touch "$env1/test/a/fixture_test.json"

union_out=$(
  cd "$env1"
  for i in 0 1 2 3; do
    python3 -I scripts/test_shard.py list "$i" 4
  done | sort
)

expected_all_11=$(
  cd "$env1"
  find test -name '*_test.dart' | sort
)

if [ "$union_out" != "$expected_all_11" ]; then
  echo "FAIL SH3: union of shards contains unexpected files or does not match 11 tests."
  echo "Union:"
  echo "$union_out"
  exit 1
fi
echo "PASS SH3"

# -----------------------------------------------------------------------------
# SH4: invalid arguments exit non-zero
# -----------------------------------------------------------------------------
for bad_args in "4 4" "-1 4" "0 0" "x 4"; do
  set +e
  out_bad=$(cd "$env1" && python3 -I scripts/test_shard.py list $bad_args 2>&1)
  status_bad=$?
  set -e
  if [ "$status_bad" -eq 0 ]; then
    echo "FAIL SH4: expected non-zero exit for 'list $bad_args', got 0"
    exit 1
  fi
done
echo "PASS SH4"

# -----------------------------------------------------------------------------
# SH5: check 4 in empty test/ directory exits non-zero
# -----------------------------------------------------------------------------
env5="$TMP_DIR/sh5"
mkdir -p "$env5/test" "$env5/scripts"
cp "$TEST_SHARD_PY" "$env5/scripts/test_shard.py"

set +e
out_empty=$(cd "$env5" && python3 -I scripts/test_shard.py check 4 2>&1)
status_empty=$?
set -e
if [ "$status_empty" -eq 0 ]; then
  echo "FAIL SH5: expected non-zero exit for check 4 with empty test/ folder"
  exit 1
fi
echo "PASS SH5"

# -----------------------------------------------------------------------------
# SH6: check-workflow verification
# -----------------------------------------------------------------------------
env6="$TMP_DIR/sh6"
mkdir -p "$env6/scripts" "$env6/.github/workflows"
cp "$TEST_SHARD_PY" "$env6/scripts/test_shard.py"

# Good workflow
cat << 'EOF' > "$env6/.github/workflows/good.yml"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: python3 -I scripts/test_shard.py list ${{ strategy.job-index }} ${{ strategy.job-total }} > "$RUNNER_TEMP/shard_files.txt"
EOF

out_good=$(cd "$env6" && python3 -I scripts/test_shard.py check-workflow .github/workflows/good.yml)
pattern='scripts/test_shard.py list ${{ strategy.job-index }} ${{ strategy.job-total }}'
if [[ "$out_good" != *"$pattern"* ]]; then
  echo "FAIL SH6: check-workflow did not output the line: $out_good"
  exit 1
fi

# Bad workflow with total written as 4
cat << 'EOF' > "$env6/.github/workflows/bad_total.yml"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: python3 -I scripts/test_shard.py list ${{ strategy.job-index }} 4 > "$RUNNER_TEMP/shard_files.txt"
EOF

set +e
out_bad_total=$(cd "$env6" && python3 -I scripts/test_shard.py check-workflow .github/workflows/bad_total.yml 2>&1)
status_bad_total=$?
set -e
if [ "$status_bad_total" -eq 0 ]; then
  echo "FAIL SH6: expected check-workflow to fail when total is written as 4"
  exit 1
fi

# Bad workflow with two list calls
cat << 'EOF' > "$env6/.github/workflows/two_calls.yml"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: python3 -I scripts/test_shard.py list ${{ strategy.job-index }} ${{ strategy.job-total }} > "$RUNNER_TEMP/shard_files.txt"
      - run: python3 -I scripts/test_shard.py list ${{ strategy.job-index }} ${{ strategy.job-total }} > "$RUNNER_TEMP/shard_files_2.txt"
EOF

set +e
out_two=$(cd "$env6" && python3 -I scripts/test_shard.py check-workflow .github/workflows/two_calls.yml 2>&1)
status_two=$?
set -e
if [ "$status_two" -eq 0 ]; then
  echo "FAIL SH6: expected check-workflow to fail with two list calls"
  exit 1
fi

echo "PASS SH6"

# -----------------------------------------------------------------------------
# SH7 (Fix 2.4): weights-from-reports on a hand-written JSON reporter file
# -----------------------------------------------------------------------------
env7="$TMP_DIR/sh7"
mkdir -p "$env7/reports" "$env7/scripts"
cp "$TEST_SHARD_PY" "$env7/scripts/test_shard.py"
cat << 'EOF' > "$env7/reports/shard_0.json"
{"protocolVersion":"0.1.1","type":"start","time":0}
{"suite":{"id":0,"platform":"vm","path":"/workspace/test/a/alpha_test.dart"},"type":"suite","time":100}
{"test":{"id":1,"name":"loading /workspace/test/a/alpha_test.dart","suiteID":0},"type":"testStart","time":100}
{"testID":1,"result":"success","hidden":true,"type":"testDone","time":350}
{"test":{"id":2,"name":"alpha test 1","suiteID":0},"type":"testStart","time":350}
{"testID":2,"result":"success","hidden":false,"type":"testDone","time":2450}
{"suite":{"id":1,"platform":"vm","path":"/workspace/test/b/beta_test.dart"},"type":"suite","time":500}
{"test":{"id":3,"name":"loading /workspace/test/b/beta_test.dart","suiteID":1},"type":"testStart","time":500}
{"testID":3,"result":"success","hidden":true,"type":"testDone","time":800}
{"test":{"id":4,"name":"beta test 1","suiteID":1},"type":"testStart","time":800}
{"testID":4,"result":"success","hidden":false,"type":"testDone","time":1760}
{"success":true,"type":"done","time":2500}
EOF

out7=$(cd "$env7" && python3 -I scripts/test_shard.py weights-from-reports reports out_weights.json)
python3 - "$env7/out_weights.json" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
expected = {"test/a/alpha_test.dart": 2.4, "test/b/beta_test.dart": 1.3}
if data != expected:
    print(f"FAIL SH7: expected {expected}, got {data}", file=sys.stderr)
    sys.exit(1)
PYEOF
echo "PASS SH7: $out7"
