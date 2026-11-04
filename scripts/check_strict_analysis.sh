#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# Cleanup slice 7: initial ceilings at app start head
RAW_TYPE_CEILING=58
INFERENCE_CEILING=120

BACKUP="$(mktemp)"
cp analysis_options.yaml "$BACKUP"

cleanup() {
  if [ -f "$BACKUP" ]; then
    cp "$BACKUP" analysis_options.yaml
    rm -f "$BACKUP"
  fi
}
trap cleanup EXIT INT TERM

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

# Restore analysis_options.yaml immediately
cleanup
trap - EXIT INT TERM

if ! git diff --quiet -- analysis_options.yaml; then
  echo "FAIL: analysis_options.yaml modified after restore" >&2
  exit 1
fi

# If the run printed no machine-format lines at all, fail
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

echo "RAW_TYPE: $RAW_COUNT (ceiling $RAW_TYPE_CEILING)"
echo "INFERENCE: $INF_COUNT (ceiling $INFERENCE_CEILING)"
echo "OK"
