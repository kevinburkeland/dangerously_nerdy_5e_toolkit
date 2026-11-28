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
  python3 - "$base/test/shard_weights.json" << 'PYEOF'
import json, sys
w = {f"test/a/f{i:02d}_test.dart": 1.0 for i in range(10)}
w["test/b/z_test.dart"] = 1.0
with open(sys.argv[1], "w") as f:
    json.dump(w, f)
PYEOF
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
mkdir -p "$env6/scripts" "$env6/.github/workflows" "$env6/test"
cp "$TEST_SHARD_PY" "$env6/scripts/test_shard.py"
echo '{}' > "$env6/test/shard_weights.json"

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

# -----------------------------------------------------------------------------
# SH8 (Fix 2.5a): 10 files (one 100s, nine 1s) across 4 shards
# -----------------------------------------------------------------------------
env8="$TMP_DIR/sh8"
mkdir -p "$env8/test" "$env8/scripts"
cp "$TEST_SHARD_PY" "$env8/scripts/test_shard.py"
python3 - "$env8" << 'PYEOF'
import json, os, sys
base = sys.argv[1]
w = {}
for i in range(9):
    p = f"test/f{i}_test.dart"
    open(os.path.join(base, p), "w").close()
    w[p] = 1.0
p_heavy = "test/heavy_test.dart"
open(os.path.join(base, p_heavy), "w").close()
w[p_heavy] = 100.0
with open(os.path.join(base, "test", "shard_weights.json"), "w") as f:
    json.dump(w, f)
PYEOF
s0=$(cd "$env8" && python3 -I scripts/test_shard.py list 0 4)
s1=$(cd "$env8" && python3 -I scripts/test_shard.py list 1 4)
s2=$(cd "$env8" && python3 -I scripts/test_shard.py list 2 4)
s3=$(cd "$env8" && python3 -I scripts/test_shard.py list 3 4)
if [ "$s0" != "test/heavy_test.dart" ]; then
  echo "FAIL SH8: expected heavy_test.dart alone in shard 0, got: $s0" >&2
  exit 1
fi
for idx_s in "$s1" "$s2" "$s3"; do
  cnt=$(printf '%s\n' "$idx_s" | wc -l | tr -d ' ')
  if [ "$cnt" -ne 3 ]; then
    echo "FAIL SH8: expected 3 files in non-heavy shard, got $cnt: $idx_s" >&2
    exit 1
  fi
done
echo "PASS SH8"

# -----------------------------------------------------------------------------
# SH9 (Fix 2.5b): missing file from weights gets median weight
# -----------------------------------------------------------------------------
env9="$TMP_DIR/sh9"
mkdir -p "$env9/test" "$env9/scripts"
cp "$TEST_SHARD_PY" "$env9/scripts/test_shard.py"
python3 - "$env9" << 'PYEOF'
import json, os, sys
base = sys.argv[1]
# Known weights: 1.0, 5.0, 9.0 -> median = 5.0.
# 4 shards. f_a (9.0) -> shard 0; f_new (median 5.0) & f_b (5.0): f_b < f_new so f_b -> shard 1, f_new -> shard 2; f_c (1.0) -> shard 3.
for name in ["f_a", "f_b", "f_c", "f_new"]:
    open(os.path.join(base, f"test/{name}_test.dart"), "w").close()
w = {"test/f_a_test.dart": 9.0, "test/f_b_test.dart": 5.0, "test/f_c_test.dart": 1.0}
with open(os.path.join(base, "test", "shard_weights.json"), "w") as f:
    json.dump(w, f)
PYEOF
s9_2=$(cd "$env9" && python3 -I scripts/test_shard.py list 2 4)
if [ "$s9_2" != "test/f_new_test.dart" ]; then
  echo "FAIL SH9: expected f_new_test.dart (median 5.0) in shard 2, got: $s9_2" >&2
  exit 1
fi
echo "PASS SH9: missing file got median 5.0 and landed in shard 2 ($s9_2)"

# -----------------------------------------------------------------------------
# SH10 (Fix 2.5c): stale entry makes check fail naming path, list still works
# -----------------------------------------------------------------------------
env10="$TMP_DIR/sh10"
cp -r "$env9" "$env10"
python3 - "$env10/test/shard_weights.json" << 'PYEOF'
import json, sys
w = json.load(open(sys.argv[1]))
w["test/deleted_stale_test.dart"] = 2.0
json.dump(w, open(sys.argv[1], "w"))
PYEOF
set +e
out10_check=$(cd "$env10" && python3 -I scripts/test_shard.py check 4 2>&1)
rc10_check=$?
set -e
if [ "$rc10_check" -eq 0 ] || [[ "$out10_check" != *"test/deleted_stale_test.dart"* ]]; then
  echo "FAIL SH10: expected check to fail naming stale path, got rc=$rc10_check: $out10_check" >&2
  exit 1
fi
out10_list=$(cd "$env10" && python3 -I scripts/test_shard.py list 0 4)
if [ "$out10_list" != "test/f_a_test.dart" ]; then
  echo "FAIL SH10: expected list to still work with stale entry, got: $out10_list" >&2
  exit 1
fi
echo "PASS SH10"

# -----------------------------------------------------------------------------
# SH11 (Fix 2.5d): malformed weights cases fail naming file and bad value
# -----------------------------------------------------------------------------
env11="$TMP_DIR/sh11"
cp -r "$env9" "$env11"
rm "$env11/test/shard_weights.json"
set +e
out11_miss=$(cd "$env11" && python3 -I scripts/test_shard.py check 4 2>&1)
rc11_miss=$?
set -e
if [ "$rc11_miss" -eq 0 ] || [[ "$out11_miss" != *"shard_weights.json"* ]]; then
  echo "FAIL SH11: missing weights file should fail naming shard_weights.json, got: $out11_miss" >&2
  exit 1
fi

for bad_json in '{bad' '{"test/f_a_test.dart": "fast"}' '{"test/f_a_test.dart": 0}' '{"test/f_a_test.dart": -1.5}' '{"test/f_a_test.dart": NaN}' '{"test/f_a_test.dart": true}'; do
  printf '%s\n' "$bad_json" > "$env11/test/shard_weights.json"
  set +e
  out11=$(cd "$env11" && python3 -I scripts/test_shard.py check 4 2>&1)
  rc11=$?
  set -e
  if [ "$rc11" -eq 0 ] || [[ "$out11" != *"shard_weights.json"* ]]; then
    echo "FAIL SH11: expected failure naming shard_weights.json for '$bad_json', got rc=$rc11: $out11" >&2
    exit 1
  fi
done
echo "PASS SH11"

# -----------------------------------------------------------------------------
# SH12 (Fix 2.5e): adding one light file changes few shards
# -----------------------------------------------------------------------------
env12="$TMP_DIR/sh12"
mkdir -p "$env12/test" "$env12/scripts"
cp "$TEST_SHARD_PY" "$env12/scripts/test_shard.py"
python3 - "$env12" << 'PYEOF'
import json, os, sys
base = sys.argv[1]
w = {}
for i in range(20):
    p = f"test/f{i:02d}_test.dart"
    open(os.path.join(base, p), "w").close()
    w[p] = float(20 - i)
with open(os.path.join(base, "test", "shard_weights.json"), "w") as f:
    json.dump(w, f)
PYEOF
before12=$(cd "$env12" && for i in 0 1 2 3; do python3 -I scripts/test_shard.py list "$i" 4 | sed "s/^/$i:/"; done | sort)
touch "$env12/test/aa_new_light_test.dart"
python3 - "$env12/test/shard_weights.json" << 'PYEOF'
import json, sys
w = json.load(open(sys.argv[1]))
w["test/aa_new_light_test.dart"] = 0.5
json.dump(w, open(sys.argv[1], "w"))
PYEOF
after12=$(cd "$env12" && for i in 0 1 2 3; do python3 -I scripts/test_shard.py list "$i" 4 | sed "s/^/$i:/"; done | sort)
moved12=$(python3 -c "
b = dict(l.split(':',1)[::-1] for l in '''$before12'''.splitlines())
a = dict(l.split(':',1)[::-1] for l in '''$after12'''.splitlines())
print(sum(1 for k, v in b.items() if a.get(k) != v))
")
if [ "$moved12" -gt 4 ]; then
  echo "FAIL SH12: adding 1 light file moved $moved12 files (expected <= 4)" >&2
  exit 1
fi
echo "PASS SH12: adding 1 light file moved $moved12 of 20 existing files"

# -----------------------------------------------------------------------------
# SH13 (Fix 2.5f): drift warnings (>10% unweighted, >1.15x slowest/avg) and no warning on balanced tree
# -----------------------------------------------------------------------------
env13="$TMP_DIR/sh13"
cp -r "$env12" "$env13"
out13_clean=$(cd "$env13" && python3 -I scripts/test_shard.py check 4 2>&1)
if [[ "$out13_clean" == *"::warning::"* ]]; then
  echo "FAIL SH13: unexpected warning on balanced tree: $out13_clean" >&2
  exit 1
fi
# >10% unweighted warning
for j in 1 2 3 4; do touch "$env13/test/unweighted_${j}_test.dart"; done
out13_unw=$(cd "$env13" && python3 -I scripts/test_shard.py check 4 2>&1)
if [[ "$out13_unw" != *"::warning::"* ]]; then
  echo "FAIL SH13: expected ::warning:: for >10% unweighted files, got: $out13_unw" >&2
  exit 1
fi
# >1.15x imbalance warning (using env8 which has 100 vs 3)
out13_imb=$(cd "$env8" && python3 -I scripts/test_shard.py check 4 2>&1)
if [[ "$out13_imb" != *"::warning::"* ]]; then
  echo "FAIL SH13: expected ::warning:: for >1.15x imbalance, got: $out13_imb" >&2
  exit 1
fi
echo "PASS SH13"

# -----------------------------------------------------------------------------
# SH14 (Fix 2.5 law): seeded random inputs invariant
# -----------------------------------------------------------------------------
PYTHONPATH="$SCRIPT_DIR" python3 - << 'PYEOF'
import random, sys
import test_shard

rng = random.Random(20261127)
for case_idx in range(300):
    n_files = rng.choice([0, 1, 2, 4, 7, 15, 50, 200, 600])
    total = rng.randint(1, 8)
    files = sorted(f"test/d{i // 20}/f{i:04d}_test.dart" for i in range(n_files))
    mode = case_idx % 4
    if mode == 0:
        weights = {f: 1.0 for f in files}
    elif mode == 1 and files:
        weights = {f: 1.0 for f in files}
        weights[rng.choice(files)] = 500.0
    elif mode == 2:
        weights = {f: float(rng.choice([0.1, 0.5, 1.0, 1.0, 2.5, 10.0, 25.0])) for f in files}
    else:
        weights = {f: round(rng.uniform(0.1, 50.0), 1) for f in files if rng.random() > 0.15}

    shards1, totals1 = test_shard.assign_shards(files, weights, total)
    shards2, totals2 = test_shard.assign_shards(files, weights, total)
    if shards1 != shards2 or totals1 != totals2:
        print(f"FAIL SH14 seed=20261127 case={case_idx}: determinism failed", file=sys.stderr)
        sys.exit(1)

    flat = [f for s in shards1 for f in s]
    if len(flat) != len(set(flat)) or sorted(flat) != sorted(files):
        print(f"FAIL SH14 seed=20261127 case={case_idx}: partition/union failed", file=sys.stderr)
        sys.exit(1)

    if len(files) >= total and any(len(s) == 0 for s in shards1):
        print(f"FAIL SH14 seed=20261127 case={case_idx}: empty shard with {len(files)} files and {total} shards", file=sys.stderr)
        sys.exit(1)

    if files:
        eff = test_shard.effective_weights(files, weights)
        max_w = max(eff.values())
        avg = sum(eff.values()) / total
        if max(totals1) > avg + max_w + 1e-9:
            print(f"FAIL SH14 seed=20261127 case={case_idx}: slowest shard {max(totals1):.2f} > avg+max_w {avg + max_w:.2f}", file=sys.stderr)
            sys.exit(1)

print("PASS SH14: 300 seeded cases passed")
PYEOF
