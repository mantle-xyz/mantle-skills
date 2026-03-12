#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

EVALS_DIR="$TMPDIR/evals"
SPECS_DIR="$EVALS_DIR/specs"
RUNNER_LIB="$TMPDIR/run-lib.sh"

mkdir -p "$SPECS_DIR"

cat > "$SPECS_DIR/alpha.yaml" <<'EOF'
skill: alpha-skill
skill_path: skills/mantle-network-primer/SKILL.md
reference_paths: []
description: alpha
evals: []
EOF

cat > "$SPECS_DIR/beta.yaml" <<'EOF'
skill: beta-skill
skill_path: skills/mantle-network-primer/SKILL.md
reference_paths: []
description: beta
evals: []
EOF

sed '/^main "\$@"$/d' "$REPO_ROOT/evals/runner/run.sh" > "$RUNNER_LIB"
# shellcheck disable=SC1090
source "$RUNNER_LIB"

EVALS_DIR="$EVALS_DIR"
EVAL_SPECS_DIR="$SPECS_DIR"

ensure_yaml_backend

skills_output=$(list_skills)
[[ "$skills_output" == $'alpha\nbeta' ]]

resolved_by_slug=$(resolve_eval_file "alpha")
[[ "$resolved_by_slug" == "$SPECS_DIR/alpha.yaml" ]]

resolved_by_skill_name=$(resolve_eval_file "beta-skill")
[[ "$resolved_by_skill_name" == "$SPECS_DIR/beta.yaml" ]]
