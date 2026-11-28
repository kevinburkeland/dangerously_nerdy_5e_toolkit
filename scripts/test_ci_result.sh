#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_SCRIPT="$SCRIPT_DIR/ci_result.py"

run_case() {
  local name="$1"
  local expect_rc="$2"
  shift 2
  set +e
  out=$(python3 -I "$RESULT_SCRIPT" "$@" 2>&1)
  rc=$?
  set -e
  if [ "$expect_rc" -eq 0 ] && [ "$rc" -ne 0 ]; then
    echo "FAIL $name: expected exit 0, got $rc: $out" >&2
    exit 1
  fi
  if [ "$expect_rc" -ne 0 ] && [ "$rc" -eq 0 ]; then
    echo "FAIL $name: expected non-zero exit, got 0: $out" >&2
    exit 1
  fi
  echo "PASS $name"
}

# 1. All success on full (with notes-text-checks skipped) passes
run_case "CR1_full_success" 0 --scope full \
  --job scope=success --job analyze=success --job dependencies=success \
  --job test=success --job web-tests=success --job tests-complete=success \
  --job firestore-rules=success --job build-web=success \
  --job dco=success --job notes-shas=success --job notes-text-checks=skipped

# 2. Heavy job failed on full fails
run_case "CR2_heavy_failed_full" 1 --scope full \
  --job scope=success --job analyze=failure --job dependencies=success \
  --job test=success --job web-tests=success --job tests-complete=success \
  --job firestore-rules=success --job build-web=success \
  --job dco=success --job notes-shas=success --job notes-text-checks=skipped

# 3. Heavy job skipped on full fails
run_case "CR3_heavy_skipped_full" 1 --scope full \
  --job scope=success --job analyze=success --job dependencies=skipped \
  --job test=success --job web-tests=success --job tests-complete=success \
  --job firestore-rules=success --job build-web=success \
  --job dco=success --job notes-shas=success --job notes-text-checks=skipped

# 4. Heavy jobs skipped on notes-only with notes-text-checks, dco, notes-shas green passes
run_case "CR4_notes_only_success" 0 --scope notes-only \
  --job scope=success --job analyze=skipped --job dependencies=skipped \
  --job test=skipped --job web-tests=skipped --job tests-complete=skipped \
  --job firestore-rules=skipped --job build-web=skipped \
  --job dco=success --job notes-shas=success --job notes-text-checks=success

# 5. notes-text-checks failed on notes-only fails
run_case "CR5_notes_text_failed" 1 --scope notes-only \
  --job scope=success --job analyze=skipped --job dependencies=skipped \
  --job test=skipped --job web-tests=skipped --job tests-complete=skipped \
  --job firestore-rules=skipped --job build-web=skipped \
  --job dco=success --job notes-shas=success --job notes-text-checks=failure

# 6. dco or notes-shas skipped for any reason fails
run_case "CR6a_dco_skipped" 1 --scope notes-only \
  --job scope=success --job analyze=skipped --job dependencies=skipped \
  --job test=skipped --job web-tests=skipped --job tests-complete=skipped \
  --job firestore-rules=skipped --job build-web=skipped \
  --job dco=skipped --job notes-shas=success --job notes-text-checks=success

run_case "CR6b_notes_shas_skipped" 1 --scope full \
  --job scope=success --job analyze=success --job dependencies=success \
  --job test=success --job web-tests=success --job tests-complete=success \
  --job firestore-rules=success --job build-web=success \
  --job dco=success --job notes-shas=skipped --job notes-text-checks=skipped

# 7. scope job failed fails
run_case "CR7_scope_failed" 1 --scope full \
  --job scope=failure --job analyze=skipped --job dependencies=skipped \
  --job test=skipped --job web-tests=skipped --job tests-complete=skipped \
  --job firestore-rules=skipped --job build-web=skipped \
  --job dco=success --job notes-shas=success --job notes-text-checks=skipped

echo "All CI result self-tests passed (CR1 - CR7)."
