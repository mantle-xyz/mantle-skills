#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

usage() {
  cat <<'EOF'
Usage: ./evals/runner/load-skill.sh <skill_path> [reference_path...]

Bundles a repo-local skill file plus any references/assets into a single
prompt-friendly document with explicit section headers.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

resolve_path() {
  local candidate="$1"
  if [[ "$candidate" = /* ]]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "$REPO_ROOT/$candidate"
  fi
}

emit_section() {
  local start_label="$1"
  local end_label="$2"
  local file_path="$3"

  if [[ ! -f "$file_path" ]]; then
    printf 'error: missing file: %s\n' "$file_path" >&2
    exit 1
  fi

  printf '%s\n' "$start_label"
  cat "$file_path"
  printf '\n%s\n' "$end_label"
}

skill_path=$(resolve_path "$1")
shift

emit_section "--- SKILL ---" "--- END SKILL ---" "$skill_path"

for reference in "$@"; do
  reference_path=$(resolve_path "$reference")
  reference_name=$(basename "$reference_path")
  emit_section "--- REFERENCE: $reference_name ---" "--- END REFERENCE ---" "$reference_path"
done
