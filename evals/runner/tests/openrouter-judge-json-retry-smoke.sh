#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/fake-bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="${TEST_STATE_FILE:?}"
count=0
if [[ -f "$STATE_FILE" ]]; then
  count=$(cat "$STATE_FILE")
fi
count=$((count + 1))
printf '%s' "$count" >"$STATE_FILE"

if [[ "$count" == "1" ]]; then
  cat <<'JSON'
{"choices":[{"message":{"content":"{\"verdict\":\"PASS\""}}]}
JSON
  exit 0
fi

cat <<'JSON'
{"choices":[{"message":{"content":"{\"verdict\":\"PASS\",\"expected_hits\":[],\"expected_misses\":[],\"fail_triggers\":[],\"reasoning\":\"ok\"}"}}]}
JSON
EOF
chmod +x "$FAKE_BIN/curl"

RUNNER_LIB="$TMP_DIR/run-lib.sh"
sed '/^main "\$@"$/d' "$REPO_ROOT/evals/runner/run.sh" >"$RUNNER_LIB"
# shellcheck disable=SC1090
source "$RUNNER_LIB"

STATE_FILE="$TMP_DIR/state.txt"
PATH="$FAKE_BIN:$PATH"
export TEST_STATE_FILE="$STATE_FILE"
export OPENROUTER_API_KEY="test-key"

result=$(judge_answer \
  "openrouter/openai/gpt-5.2" \
  "judge prompt" \
  "eval prompt" \
  "answer" \
  '["fact"]' \
  '[]')

jq -e '.verdict == "PASS"' <<<"$result" >/dev/null

if [[ "$(cat "$STATE_FILE")" -lt 2 ]]; then
  echo "expected judge parsing to retry when first response is invalid JSON" >&2
  exit 1
fi

echo "openrouter judge json retry smoke test passed"
