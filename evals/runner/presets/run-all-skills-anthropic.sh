#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required (Anthropic models are accessed via OpenRouter)}"

MODEL="${ANTHROPIC_MODEL:-openrouter/anthropic/claude-sonnet-4}"
JUDGE_MODEL="${ANTHROPIC_JUDGE_MODEL:-$MODEL}"
LABEL="${BATCH_LABEL:-anthropic-all-skills}"

"$SCRIPT_DIR/../run-all-skills.sh" \
  --model "$MODEL" \
  --judge-model "$JUDGE_MODEL" \
  --label "$LABEL" \
  "$@"
