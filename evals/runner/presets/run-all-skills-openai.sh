#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

: "${OPENAI_API_KEY:?OPENAI_API_KEY is required}"

MODEL="${OPENAI_MODEL:-openai/gpt-5.2}"
JUDGE_MODEL="${OPENAI_JUDGE_MODEL:-$MODEL}"
LABEL="${BATCH_LABEL:-openai-all-skills}"

"$SCRIPT_DIR/../run-all-skills.sh" \
  --model "$MODEL" \
  --judge-model "$JUDGE_MODEL" \
  --label "$LABEL" \
  "$@"
