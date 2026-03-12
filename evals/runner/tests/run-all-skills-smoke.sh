#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

EVALS_DIR="$TMPDIR/evals"
SPECS_DIR="$EVALS_DIR/specs"
RESULTS_DIR="$TMPDIR/results"
FAKE_RUNNER="$TMPDIR/fake-runner.sh"
mkdir -p "$SPECS_DIR" "$RESULTS_DIR"

cat > "$SPECS_DIR/alpha.yaml" <<'EOF'
skill: alpha
skill_path: skills/mantle-network-primer/SKILL.md
reference_paths: []
description: alpha
evals: []
EOF

cat > "$SPECS_DIR/beta.yaml" <<'EOF'
skill: beta
skill_path: skills/mantle-network-primer/SKILL.md
reference_paths: []
description: beta
evals: []
EOF

cat > "$FAKE_RUNNER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
skill=""
output=""
model=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) skill="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
slug=$(basename "$skill" .yaml)
jq -n --arg skill "$slug" --arg model "$model" '{
  eval_slug: $skill,
  model: $model,
  summary: {
    eval_count: 1,
    bare: {PASS: 0, PARTIAL: 0, FAIL: 1},
    skill: {PASS: 1, PARTIAL: 0, FAIL: 0},
    skill_better: 1,
    bare_better: 0,
    same: 0
  }
}' > "$output"
EOF
chmod +x "$FAKE_RUNNER"

"$REPO_ROOT/evals/runner/run-all-skills.sh" \
  --model openai/gpt-5.2 \
  --label smoke \
  --evals-dir "$EVALS_DIR" \
  --results-dir "$RESULTS_DIR" \
  --runner "$FAKE_RUNNER" >/dev/null 2>&1

SUMMARY=$(find "$RESULTS_DIR" -name summary.json | head -n 1)
[[ -n "$SUMMARY" ]]

jq -e '.models[0] == "openai/gpt-5.2"' "$SUMMARY" >/dev/null
jq -e '.skills_total == 2' "$SUMMARY" >/dev/null
jq -e '.skills_succeeded == 2' "$SUMMARY" >/dev/null
jq -e '.runs.alpha.status == "success"' "$SUMMARY" >/dev/null
jq -e '.runs.beta.status == "success"' "$SUMMARY" >/dev/null
