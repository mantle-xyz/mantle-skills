#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

stderr_file="$tmpdir/stderr.txt"
stdout_file="$tmpdir/stdout.txt"

set +e
env -u OPENROUTER_API_KEY -u OPENAI_API_KEY \
  "$REPO_ROOT/evals/runner/run.sh" \
  --skill network-primer \
  --model openrouter/openai/gpt-5.2 \
  >"$stdout_file" 2>"$stderr_file"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "expected openrouter smoke test to fail without credentials" >&2
  exit 1
fi

grep -F "OPENROUTER_API_KEY is required for provider 'openrouter'" "$stderr_file" >/dev/null
