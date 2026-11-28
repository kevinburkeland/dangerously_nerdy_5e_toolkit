#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_notes_workflow.py"
REAL_WORKFLOW="$SCRIPT_DIR/../.github/workflows/release.yml"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# NW1 (control): the real workflow passes (or a valid synthetic workflow when run before release.yml is updated)
valid_wf="$TMP_DIR/valid.yml"
cat << 'EOF' > "$valid_wf"
jobs:
  dco:
    runs-on: ubuntu-latest
    steps:
      - name: Verify Commit Sign-offs
        run: ./scripts/check_dco.sh abc HEAD
  notes-shas:
    runs-on: ubuntu-latest
    steps:
      - name: Run Notes SHA Check Script Self-Tests
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: ./scripts/test_check_notes_shas.sh
      - name: Verify Notes Commit SHAs
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: python3 -I scripts/check_notes_shas.py --repo .=kevinburkeland/dangerously_nerdy_5e_toolkit --repo "$RUNNER_TEMP/core.git=kevinburkeland/vtt-engine-core" --repo "$RUNNER_TEMP/ruleset.git=kevinburkeland/vtt-ruleset-dnd5e" notes/*.md
EOF

out1=$(python3 -I "$CHECK_SCRIPT" "$valid_wf" 2>&1)
if [[ "$out1" != *"OK"* ]]; then
  echo "FAIL NW1: expected valid workflow to pass, got: $out1" >&2
  exit 1
fi
echo "PASS NW1"

# NW2: a copy with the live step deleted fails
no_live="$TMP_DIR/no_live.yml"
grep -v "check_notes_shas.py" "$valid_wf" > "$no_live"
set +e
out2=$(python3 -I "$CHECK_SCRIPT" "$no_live" 2>&1)
rc2=$?
set -e
if [ "$rc2" -eq 0 ]; then
  echo "FAIL NW2: expected failure when live step deleted" >&2
  exit 1
fi
echo "PASS NW2"

# NW3: a copy with one --repo pair removed fails, naming the missing --repo pair
missing_repo="$TMP_DIR/missing_repo.yml"
sed 's/--repo "\$RUNNER_TEMP\/core\.git=kevinburkeland\/vtt-engine-core" //' "$valid_wf" > "$missing_repo"
set +e
out3=$(python3 -I "$CHECK_SCRIPT" "$missing_repo" 2>&1)
rc3=$?
set -e
if [ "$rc3" -eq 0 ] || [[ "$out3" != *"kevinburkeland/vtt-engine-core"* ]]; then
  echo "FAIL NW3: expected failure naming missing --repo pair, got rc=$rc3: $out3" >&2
  exit 1
fi
echo "PASS NW3"

# NW4: a copy where the step runs over one notes file instead of notes/*.md fails
single_file="$TMP_DIR/single_file.yml"
sed 's|notes/\*\.md|notes/cleanup_slice_19_progress.md|' "$valid_wf" > "$single_file"
set +e
out4=$(python3 -I "$CHECK_SCRIPT" "$single_file" 2>&1)
rc4=$?
set -e
if [ "$rc4" -eq 0 ] || [[ "$out4" != *"notes/*.md"* ]]; then
  echo "FAIL NW4: expected failure naming notes/*.md, got rc=$rc4: $out4" >&2
  exit 1
fi
echo "PASS NW4"

# NW5: a copy with two such steps fails
two_steps="$TMP_DIR/two_steps.yml"
cat "$valid_wf" > "$two_steps"
cat << 'EOF' >> "$two_steps"
      - name: Duplicate Verify Notes Commit SHAs
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: python3 -I scripts/check_notes_shas.py --repo .=kevinburkeland/dangerously_nerdy_5e_toolkit --repo "$RUNNER_TEMP/core.git=kevinburkeland/vtt-engine-core" --repo "$RUNNER_TEMP/ruleset.git=kevinburkeland/vtt-ruleset-dnd5e" notes/*.md
EOF
set +e
out5=$(python3 -I "$CHECK_SCRIPT" "$two_steps" 2>&1)
rc5=$?
set -e
if [ "$rc5" -eq 0 ] || [[ "$out5" != *"2"* ]]; then
  echo "FAIL NW5: expected failure for two live steps, got rc=$rc5: $out5" >&2
  exit 1
fi
echo "PASS NW5"

# NW6: a copy with the notes self-test step put back into the dco job fails
in_dco="$TMP_DIR/in_dco.yml"
cat << 'EOF' > "$in_dco"
jobs:
  dco:
    runs-on: ubuntu-latest
    steps:
      - name: Run Notes SHA Check Script Self-Tests
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: ./scripts/test_check_notes_shas.sh
  notes-shas:
    runs-on: ubuntu-latest
    steps:
      - name: Verify Notes Commit SHAs
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: python3 -I scripts/check_notes_shas.py --repo .=kevinburkeland/dangerously_nerdy_5e_toolkit --repo "$RUNNER_TEMP/core.git=kevinburkeland/vtt-engine-core" --repo "$RUNNER_TEMP/ruleset.git=kevinburkeland/vtt-ruleset-dnd5e" notes/*.md
EOF
set +e
out6=$(python3 -I "$CHECK_SCRIPT" "$in_dco" 2>&1)
rc6=$?
set -e
if [ "$rc6" -eq 0 ] || [[ "$out6" != *"dco"* ]]; then
  echo "FAIL NW6: expected failure naming dco job, got rc=$rc6: $out6" >&2
  exit 1
fi
echo "PASS NW6"

# NW7 (control): the real workflow passes
if [ -f "$REAL_WORKFLOW" ]; then
  out7=$(python3 -I "$CHECK_SCRIPT" "$REAL_WORKFLOW" 2>&1)
  if [[ "$out7" != *"OK"* ]]; then
    echo "FAIL NW7: expected real workflow to pass, got: $out7" >&2
    exit 1
  fi
  echo "PASS NW7"
fi

echo "All notes workflow check self-tests passed (NW1 - NW7)."
