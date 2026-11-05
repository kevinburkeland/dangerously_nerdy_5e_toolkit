#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

IGNORE_COUNT=51
RAW_TYPE_CEILING=58
INFERENCE_CEILING=105

# --- Phase 1: Validate analysis_options.yaml ---
python3 - << 'PYEOF'
import sys

with open('analysis_options.yaml', 'r') as f:
    lines = f.readlines()

has_strict_casts = False
has_errors_key = False
exclude_list = []
in_analyzer = False
in_language = False
in_exclude = False

for line in lines:
    raw = line.rstrip()
    stripped = raw.strip()
    if not stripped or stripped.startswith('#'):
        continue
    indent = len(raw) - len(raw.lstrip())
    if indent == 0:
        in_analyzer = (stripped == 'analyzer:')
        in_language = False
        in_exclude = False
        if stripped.startswith('errors:'):
            has_errors_key = True
    elif in_analyzer:
        if indent == 2:
            in_language = (stripped == 'language:')
            in_exclude = (stripped == 'exclude:')
            if stripped.startswith('errors:'):
                has_errors_key = True
        elif indent == 4 and in_language:
            if stripped == 'strict-casts: true':
                has_strict_casts = True
        elif indent == 4 and in_exclude:
            if stripped.startswith('- '):
                exclude_list.append(stripped[2:].strip())

if not has_strict_casts:
    print("FAIL: analysis_options.yaml has no strict-casts: true under analyzer: language:", file=sys.stderr)
    sys.exit(1)

if has_errors_key:
    print("FAIL: analysis_options.yaml has an errors: key", file=sys.stderr)
    sys.exit(1)

expected_excludes = ['build/**', 'android/**', 'web/**', 'linux/**', 'firestore_rules_test/**']
if exclude_list != expected_excludes:
    print(f"FAIL: analyzer: exclude: list changed (got {exclude_list}, expected {expected_excludes})", file=sys.stderr)
    sys.exit(1)
PYEOF

# --- Phase 2: Validate ignore comments and count ---
python3 - << PYEOF
import os, re, sys

IGNORE_COUNT = $IGNORE_COUNT

FORBIDDEN = {
    'argument_type_not_assignable',
    'invalid_assignment',
    'for_in_of_invalid_type',
    'non_bool_condition',
    'non_bool_operand',
    'non_bool_negation_expression',
    'return_of_invalid_type',
    'return_of_invalid_type_from_closure',
    'invalid_return_type_for_then',
    'strict_raw_type',
}

ignore_pattern = re.compile(r'//\s*ignore(_for_file)?:\s*([^\n\r]+)')

total_ignores = 0
violations = []

for root_dir in ['lib', 'test']:
    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if fname.endswith('.dart'):
                fpath = os.path.join(dirpath, fname)
                with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
                    for lnum, line in enumerate(f, 1):
                        match = ignore_pattern.search(line)
                        if match:
                            total_ignores += 1
                            codes_str = match.group(2).strip()
                            codes = [c.strip() for c in codes_str.split(',') if c.strip()]
                            for code in codes:
                                code_clean = code.split()[0] if code.split() else ''
                                if code_clean in FORBIDDEN or code_clean.startswith('inference_failure_on_'):
                                    violations.append((fpath, lnum, code_clean))

if violations:
    for fpath, lnum, code in violations:
        print(f"FAIL: forbidden ignore code '{code}' in {fpath}:{lnum}", file=sys.stderr)
    sys.exit(1)

if total_ignores != IGNORE_COUNT:
    print(f"FAIL: total ignore count {total_ignores} differs from IGNORE_COUNT {IGNORE_COUNT}", file=sys.stderr)
    sys.exit(1)
PYEOF

# --- Phase 3: The Canary ---
CANARY="lib/zz_strict_canary.dart"
cleanup_canary() {
  rm -f "$CANARY"
}
trap cleanup_canary EXIT INT TERM

echo "int canaryCast(dynamic x) => x;" > "$CANARY"

set +e
CANARY_OUT="$(flutter analyze 2>&1)"
CANARY_STATUS=$?
set -e

cleanup_canary
trap - EXIT INT TERM

if [ "$CANARY_STATUS" -eq 0 ]; then
  echo "FAIL: canary analysis succeeded (expected non-zero exit under strict-casts)" >&2
  exit 1
fi

if ! grep -q "return_of_invalid_type" <<< "$CANARY_OUT" || ! grep -q "zz_strict_canary.dart" <<< "$CANARY_OUT"; then
  echo "FAIL: canary did not report return_of_invalid_type at zz_strict_canary.dart" >&2
  echo "$CANARY_OUT" >&2
  exit 1
fi

if git status --porcelain "$CANARY" | grep -q .; then
  echo "FAIL: git status shows canary file left behind" >&2
  exit 1
fi

# --- Phase 4: Ceilings on implicit dynamic (strict-raw-types & strict-inference) ---
BACKUP="$(mktemp)"
cp analysis_options.yaml "$BACKUP"

cleanup_options() {
  if [ -f "$BACKUP" ]; then
    cp "$BACKUP" analysis_options.yaml
    rm -f "$BACKUP"
  fi
}
trap cleanup_options EXIT INT TERM

# Insert strict-raw-types and strict-inference under analyzer: language:
python3 -c "
with open('analysis_options.yaml', 'r') as f:
    c = f.read()
if '  language:\n' in c:
    c = c.replace('  language:\n', '  language:\n    strict-raw-types: true\n    strict-inference: true\n', 1)
else:
    c = c.replace('analyzer:\n', 'analyzer:\n  language:\n    strict-raw-types: true\n    strict-inference: true\n', 1)
with open('analysis_options.yaml', 'w') as f:
    f.write(c)
"

set +e
OUTPUT="$(dart analyze --format=machine 2>&1)"
set -e

# Restore analysis_options.yaml from backup
cp "$BACKUP" analysis_options.yaml

if ! cmp -s "$BACKUP" analysis_options.yaml; then
  echo "FAIL: analysis_options.yaml differs from backup" >&2
  rm -f "$BACKUP"
  exit 1
fi

rm -f "$BACKUP"
trap - EXIT INT TERM

if ! grep -qE '^(INFO|WARNING|ERROR)\|' <<< "$OUTPUT"; then
  echo "FAIL: dart analyze did not output machine format lines" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

LIB_DIR="$REPO_DIR/lib/"
RAW_MATCHES="$(grep -F "|STRICT_RAW_TYPE|" <<< "$OUTPUT" | grep -F "|$LIB_DIR" || true)"
INF_MATCHES="$(grep -E '\|INFERENCE_FAILURE_ON_[^|]+\|' <<< "$OUTPUT" | grep -F "|$LIB_DIR" || true)"

if [ -z "$RAW_MATCHES" ]; then
  RAW_COUNT=0
else
  RAW_COUNT="$(grep -c . <<< "$RAW_MATCHES")"
fi

if [ -z "$INF_MATCHES" ]; then
  INF_COUNT=0
else
  INF_COUNT="$(grep -c . <<< "$INF_MATCHES")"
fi

FAILED=0

if [ "$RAW_COUNT" -gt "$RAW_TYPE_CEILING" ]; then
  echo "FAIL: STRICT_RAW_TYPE count $RAW_COUNT exceeds ceiling $RAW_TYPE_CEILING" >&2
  echo "$RAW_MATCHES" >&2
  FAILED=1
elif [ "$RAW_COUNT" -lt "$RAW_TYPE_CEILING" ]; then
  echo "FAIL: lower RAW_TYPE_CEILING to $RAW_COUNT" >&2
  FAILED=1
fi

if [ "$INF_COUNT" -gt "$INFERENCE_CEILING" ]; then
  echo "FAIL: INFERENCE_FAILURE count $INF_COUNT exceeds ceiling $INFERENCE_CEILING" >&2
  echo "$INF_MATCHES" >&2
  FAILED=1
elif [ "$INF_COUNT" -lt "$INFERENCE_CEILING" ]; then
  echo "FAIL: lower INFERENCE_CEILING to $INF_COUNT" >&2
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "ANALYSIS_OPTIONS: OK"
echo "IGNORE_COMMENTS: $IGNORE_COUNT (expected $IGNORE_COUNT)"
echo "CANARY: OK (caught return_of_invalid_type)"
echo "RAW_TYPE: $RAW_COUNT (ceiling $RAW_TYPE_CEILING)"
echo "INFERENCE: $INF_COUNT (ceiling $INFERENCE_CEILING)"
echo "OK"
