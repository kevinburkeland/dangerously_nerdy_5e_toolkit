#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_SCRIPT="$SCRIPT_DIR/ci_scope.py"

TMP_DIR=$(mktemp -d)
SERVER_PID=""
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

SERVER_DIR="$TMP_DIR/server"
mkdir -p "$SERVER_DIR"
PORT_FILE="$TMP_DIR/server.port"

(
  cd "$SERVER_DIR"
  python3 -c "
import http.server, socketserver, os, urllib.parse

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    def do_GET(self):
        if os.path.exists('server.sleep'):
            import time
            time.sleep(float(open('server.sleep').read().strip()))
        if os.path.exists('server.status'):
            code = int(open('server.status').read().strip())
            self.send_response(code)
            self.end_headers()
            self.wfile.write(b'error')
            return
        parsed = urllib.parse.urlparse(self.path)
        rel = parsed.path.strip('/') + '.json'
        if os.path.exists(rel):
            data = open(rel, 'rb').read()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_response(404)
        self.end_headers()

with socketserver.TCPServer(('127.0.0.1', 0), Handler) as httpd:
    open('$PORT_FILE', 'w').write(str(httpd.server_address[1]))
    httpd.serve_forever()
"
) &
SERVER_PID=$!
while [ ! -s "$PORT_FILE" ]; do sleep 0.05; done
API_BASE="http://127.0.0.1:$(cat "$PORT_FILE")"

setup_repo() {
  local dir="$1"
  mkdir -p "$dir/notes"
  git -C "$dir" init -b main >/dev/null 2>&1
  git -C "$dir" config user.name "Test"
  git -C "$dir" config user.email "test@example.com"
  echo "base" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -m "base" >/dev/null
}

write_runs() {
  local json_body="$1"
  mkdir -p "$SERVER_DIR/repos/org/repo/actions"
  printf '%s' "$json_body" > "$SERVER_DIR/repos/org/repo/actions/runs.json"
}

# (a) control: notes-only commit on parent with green run -> notes-only
repo_a="$TMP_DIR/repo_a"
setup_repo "$repo_a"
parent_a=$(git -C "$repo_a" rev-parse HEAD)
echo "note" > "$repo_a/notes/p.md"
git -C "$repo_a" add notes/p.md && git -C "$repo_a" commit -m "notes" >/dev/null
write_runs "{\"workflow_runs\":[{\"id\":1001,\"head_sha\":\"$parent_a\",\"status\":\"completed\",\"conclusion\":\"success\",\"path\":\".github/workflows/release.yml\"}]}"
out_a=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
if [[ "$out_a" != *"scope=notes-only"* ]] || [[ "$out_a" != *"parent=$parent_a"* ]] || [[ "$out_a" != *"parent_run=1001"* ]]; then
  echo "FAIL (a): expected notes-only with parent and run 1001, got: $out_a" >&2
  exit 1
fi
echo "PASS (a): $out_a"

# (b) parent's only run failed -> full
write_runs "{\"workflow_runs\":[{\"id\":1002,\"head_sha\":\"$parent_a\",\"status\":\"completed\",\"conclusion\":\"failure\",\"path\":\".github/workflows/release.yml\"}]}"
out_b=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_b" == "scope=full "* ]] || { echo "FAIL (b): expected scope=full, got: $out_b" >&2; exit 1; }
echo "PASS (b): $out_b"

# (c) parent has no run -> full
write_runs '{"workflow_runs":[]}'
out_c=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_c" == "scope=full "* ]] || { echo "FAIL (c): expected scope=full, got: $out_c" >&2; exit 1; }
echo "PASS (c): $out_c"

# (d) parent's green run has a different head_sha -> full
write_runs '{"workflow_runs":[{"id":1003,"head_sha":"0000000000000000000000000000000000000000","status":"completed","conclusion":"success","path":".github/workflows/release.yml"}]}'
out_d=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_d" == "scope=full "* ]] || { echo "FAIL (d): expected scope=full, got: $out_d" >&2; exit 1; }
echo "PASS (d): $out_d"

# (e) notes/ plus CHANGELOG.md, notes.md at root, or test/notes/x_test.dart -> full
write_runs "{\"workflow_runs\":[{\"id\":1001,\"head_sha\":\"$parent_a\",\"status\":\"completed\",\"conclusion\":\"success\",\"path\":\".github/workflows/release.yml\"}]}"
for extra in "CHANGELOG.md" "notes.md" "test/notes/x_test.dart"; do
  repo_e="$TMP_DIR/repo_e_$(echo "$extra" | tr '/.' '__')"
  setup_repo "$repo_e"
  p_e=$(git -C "$repo_e" rev-parse HEAD)
  write_runs "{\"workflow_runs\":[{\"id\":1001,\"head_sha\":\"$p_e\",\"status\":\"completed\",\"conclusion\":\"success\",\"path\":\".github/workflows/release.yml\"}]}"
  mkdir -p "$repo_e/$(dirname "$extra")"
  echo "x" > "$repo_e/notes/p.md"
  echo "y" > "$repo_e/$extra"
  git -C "$repo_e" add . && git -C "$repo_e" commit -m "mixed" >/dev/null
  out_e=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_e" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
  [[ "$out_e" == "scope=full "* ]] || { echo "FAIL (e) $extra: expected scope=full, got: $out_e" >&2; exit 1; }
done
echo "PASS (e)"

# (f) merge commit -> full
repo_f="$TMP_DIR/repo_f"
setup_repo "$repo_f"
git -C "$repo_f" checkout -b side >/dev/null 2>&1
echo "s" > "$repo_f/notes/side.md"
git -C "$repo_f" add notes/side.md && git -C "$repo_f" commit -m "side" >/dev/null
git -C "$repo_f" checkout main >/dev/null 2>&1
echo "m" > "$repo_f/notes/main.md"
git -C "$repo_f" add notes/main.md && git -C "$repo_f" commit -m "main" >/dev/null
p_f=$(git -C "$repo_f" rev-parse HEAD)
git -C "$repo_f" merge --no-ff side -m "merge" >/dev/null 2>&1
write_runs "{\"workflow_runs\":[{\"id\":1005,\"head_sha\":\"$p_f\",\"status\":\"completed\",\"conclusion\":\"success\",\"path\":\".github/workflows/release.yml\"}]}"
out_f=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_f" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_f" == "scope=full "* ]] || { echo "FAIL (f): expected scope=full, got: $out_f" >&2; exit 1; }
echo "PASS (f): $out_f"

# (g) API 500, timeout, or unreachable -> full
write_runs "{\"workflow_runs\":[{\"id\":1001,\"head_sha\":\"$parent_a\",\"status\":\"completed\",\"conclusion\":\"success\",\"path\":\".github/workflows/release.yml\"}]}"
echo "500" > "$SERVER_DIR/server.status"
out_g1=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
rm "$SERVER_DIR/server.status"
[[ "$out_g1" == "scope=full "* ]] || { echo "FAIL (g1): expected scope=full on 500, got: $out_g1" >&2; exit 1; }
out_g2=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "http://127.0.0.1:65534")
[[ "$out_g2" == "scope=full "* ]] || { echo "FAIL (g2): expected scope=full on unreachable, got: $out_g2" >&2; exit 1; }
echo "PASS (g)"

# (h) no token -> full
out_h=$(GITHUB_TOKEN="" python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event push --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_h" == "scope=full "* ]] || { echo "FAIL (h): expected scope=full without token, got: $out_h" >&2; exit 1; }
echo "PASS (h): $out_h"

# (i) pull_request event -> full
out_i=$(GITHUB_TOKEN=tok python3 -I "$SCOPE_SCRIPT" --repo "$repo_a" --owner-repo org/repo --event pull_request --ref refs/heads/main --workflow release.yml --api-base "$API_BASE")
[[ "$out_i" == "scope=full "* ]] || { echo "FAIL (i): expected scope=full on pull_request, got: $out_i" >&2; exit 1; }
echo "PASS (i): $out_i"

# Law over 200 seeded random inputs
PYTHONPATH="$SCRIPT_DIR" python3 - << 'PYEOF'
import random, sys
import ci_scope

rng = random.Random(20261128)
for idx in range(200):
    parent_sha = f"{idx:040x}"
    other_sha = f"{idx + 1000:040x}"
    n_files = rng.randint(0, 5)
    pool = ["notes/a.md", "notes/b.md", "README.md", "CHANGELOG.md", "notes.md", "lib/x.dart", "test/notes/t.dart"]
    changed = [rng.choice(pool) for _ in range(n_files)]
    runs = []
    for r_i in range(rng.randint(0, 3)):
        runs.append({
            "id": 5000 + r_i,
            "head_sha": rng.choice([parent_sha, other_sha]),
            "status": rng.choice(["completed", "in_progress"]),
            "conclusion": rng.choice(["success", "failure", "cancelled"]),
            "path": ".github/workflows/release.yml",
        })
    api_ok = rng.random() > 0.15
    event_ok = rng.random() > 0.1
    is_merge = rng.random() < 0.1
    scope, _ = ci_scope.decide_scope(
        event_name="push" if event_ok else "pull_request",
        ref="refs/heads/main",
        changed_files=changed,
        parent_count=2 if is_merge else 1,
        parent_sha=parent_sha,
        runs=runs if api_ok else None,
        workflow_name="release.yml",
        has_token=True,
    )
    expected_notes = (
        event_ok
        and not is_merge
        and len(changed) > 0
        and all(f.startswith("notes/") for f in changed)
        and api_ok
        and any(
            r["head_sha"].lower() == parent_sha.lower()
            and r["status"] == "completed"
            and r["conclusion"] == "success"
            for r in runs
        )
    )
    expected = "notes-only" if expected_notes else "full"
    if scope != expected:
        print(f"FAIL law seed=20261128 case={idx}: expected {expected}, got {scope}", file=sys.stderr)
        sys.exit(1)
print("PASS law: 200 seeded cases passed")
PYEOF
