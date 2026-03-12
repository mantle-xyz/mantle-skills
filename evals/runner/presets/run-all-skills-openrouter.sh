#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

MODEL="${OPENROUTER_MODEL:-openrouter/arcee-ai/trinity-large-preview:free}"
JUDGE_MODEL="${OPENROUTER_JUDGE_MODEL:-$MODEL}"
LABEL="${BATCH_LABEL:-openrouter-all-skills}"

"$SCRIPT_DIR/../run-all-skills.sh" \
  --model "$MODEL" \
  --judge-model "$JUDGE_MODEL" \
  --label "$LABEL" \
  "$@"
