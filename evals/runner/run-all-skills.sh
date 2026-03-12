#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
DEFAULT_EVALS_DIR="$REPO_ROOT/evals"
DEFAULT_RESULTS_DIR="$REPO_ROOT/evals/results/batches"
DEFAULT_RUNNER="$SCRIPT_DIR/run.sh"

usage() {
  cat <<'EOF'
Usage: ./evals/runner/run-all-skills.sh --model <provider/model> [options]

Options:
  --model <value>        Required target model
  --judge-model <value>  Optional judge model; defaults to --model
  --label <value>        Optional output label; defaults to sanitized model name
  --evals-dir <path>     Optional eval root or specs directory; defaults to repo evals/
  --results-dir <path>   Optional output root; defaults to evals/results/batches/
  --runner <path>        Optional single-skill runner; defaults to evals/runner/run.sh
  --help                 Show this help text
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

sanitize_label() {
  printf '%s\n' "$1" | tr '/: ' '---' | tr -cd 'A-Za-z0-9._-'
}

resolve_eval_search_dir() {
  local evals_dir="$1"
  local specs_dir="$evals_dir/specs"

  if [[ -d "$specs_dir" ]]; then
    printf '%s\n' "$specs_dir"
  else
    printf '%s\n' "$evals_dir"
  fi
}

run_skill_with_progress() {
  local index="$1"
  local total="$2"
  local slug="$3"
  local stdout_file="$4"
  local stderr_file="$5"
  shift 5

  local heartbeat_interval="${BATCH_HEARTBEAT_SECONDS:-30}"
  local start_epoch runner_pid heartbeat_pid=""
  local status=0 elapsed

  printf '[start %s/%s] %s\n' "$index" "$total" "$slug" >&2
  printf '  stdout=%s\n' "$stdout_file" >&2
  printf '  stderr=%s\n' "$stderr_file" >&2

  start_epoch=$(date +%s)

  "$@" >"$stdout_file" 2> >(tee "$stderr_file" >&2) &
  runner_pid=$!

  if [[ "$heartbeat_interval" != "0" ]]; then
    (
      while kill -0 "$runner_pid" 2>/dev/null; do
        sleep "$heartbeat_interval"
        if kill -0 "$runner_pid" 2>/dev/null; then
          elapsed=$(( $(date +%s) - start_epoch ))
          printf '[wait %s/%s] %s elapsed=%ss stderr=%s\n' \
            "$index" "$total" "$slug" "$elapsed" "$stderr_file" >&2
        fi
      done
    ) &
    heartbeat_pid=$!
  fi

  set +e
  wait "$runner_pid"
  status=$?
  set -e

  if [[ -n "$heartbeat_pid" ]]; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
  fi

  return "$status"
}

main() {
  require_cmd jq

  local model=""
  local judge_model=""
  local label=""
  local evals_dir="$DEFAULT_EVALS_DIR"
  local results_dir="$DEFAULT_RESULTS_DIR"
  local runner="$DEFAULT_RUNNER"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)
        [[ $# -ge 2 ]] || die "--model requires a value"
        model="$2"
        shift 2
        ;;
      --judge-model)
        [[ $# -ge 2 ]] || die "--judge-model requires a value"
        judge_model="$2"
        shift 2
        ;;
      --label)
        [[ $# -ge 2 ]] || die "--label requires a value"
        label="$2"
        shift 2
        ;;
      --evals-dir)
        [[ $# -ge 2 ]] || die "--evals-dir requires a value"
        evals_dir="$2"
        shift 2
        ;;
      --results-dir)
        [[ $# -ge 2 ]] || die "--results-dir requires a value"
        results_dir="$2"
        shift 2
        ;;
      --runner)
        [[ $# -ge 2 ]] || die "--runner requires a value"
        runner="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$model" ]] || die "--model is required"
  [[ -d "$evals_dir" ]] || die "evals directory not found: $evals_dir"
  [[ -x "$runner" ]] || die "runner is not executable: $runner"

  judge_model="${judge_model:-$model}"
  label="${label:-$(sanitize_label "$model")}"

  local timestamp batch_dir logs_dir summary_file eval_search_dir
  timestamp=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
  batch_dir="$results_dir/${label}-${timestamp}"
  logs_dir="$batch_dir/logs"
  summary_file="$batch_dir/summary.json"

  mkdir -p "$logs_dir"
  eval_search_dir=$(resolve_eval_search_dir "$evals_dir")

  local -a eval_files=()
  while IFS= read -r file; do
    eval_files+=("$file")
  done < <(find "$eval_search_dir" -maxdepth 1 -name '*.yaml' -type f | sort)

  (( ${#eval_files[@]} > 0 )) || die "no eval YAML files found in: $eval_search_dir"

  local runs_json='{}'
  local skills_total=0
  local skills_succeeded=0
  local skills_failed=0
  local eval_file slug output_file stdout_file stderr_file status_json
  local total_skills index=0
  local -a runner_args

  total_skills="${#eval_files[@]}"
  printf 'Running %d skill eval file(s) with %s\n' "$total_skills" "$model" >&2
  printf 'Batch directory: %s\n' "$batch_dir" >&2
  printf 'Logs directory: %s\n' "$logs_dir" >&2
  printf 'Summary file: %s\n' "$summary_file" >&2
  printf 'Eval specs directory: %s\n' "$eval_search_dir" >&2

  for eval_file in "${eval_files[@]}"; do
    index=$((index + 1))
    slug=$(basename "$eval_file" .yaml)
    output_file="$batch_dir/${slug}.json"
    stdout_file="$logs_dir/${slug}.stdout.log"
    stderr_file="$logs_dir/${slug}.stderr.log"

    runner_args=(
      "$runner"
      --skill "$eval_file"
      --model "$model"
      --judge-model "$judge_model"
      --output "$output_file"
    )

    skills_total=$((skills_total + 1))

    if run_skill_with_progress "$index" "$total_skills" "$slug" "$stdout_file" "$stderr_file" "${runner_args[@]}"; then
      skills_succeeded=$((skills_succeeded + 1))
      status_json=$(
        jq -n \
          --arg status "success" \
          --arg eval_file "$eval_file" \
          --arg output_path "$output_file" \
          --arg stdout_log "$stdout_file" \
          --arg stderr_log "$stderr_file" \
          '{
            status: $status,
            eval_file: $eval_file,
            output_path: $output_path,
            stdout_log: $stdout_log,
            stderr_log: $stderr_log
          }'
      )
      printf '[ok] %s -> %s\n' "$slug" "$output_file" >&2
    else
      skills_failed=$((skills_failed + 1))
      status_json=$(
        jq -n \
          --arg status "failed" \
          --arg eval_file "$eval_file" \
          --arg output_path "$output_file" \
          --arg stdout_log "$stdout_file" \
          --arg stderr_log "$stderr_file" \
          '{
            status: $status,
            eval_file: $eval_file,
            output_path: $output_path,
            stdout_log: $stdout_log,
            stderr_log: $stderr_log
          }'
      )
      printf '[fail] %s -> %s\n' "$slug" "$stderr_file" >&2
    fi

    runs_json=$(jq -c --arg slug "$slug" --argjson run "$status_json" '. + {($slug): $run}' <<<"$runs_json")
  done

  jq -n \
    --arg generated_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg label "$label" \
    --arg batch_dir "$batch_dir" \
    --arg model "$model" \
    --arg judge_model "$judge_model" \
    --arg evals_dir "$evals_dir" \
    --arg eval_search_dir "$eval_search_dir" \
    --arg runner "$runner" \
    --argjson skills_total "$skills_total" \
    --argjson skills_succeeded "$skills_succeeded" \
    --argjson skills_failed "$skills_failed" \
    --argjson runs "$runs_json" \
    '{
      generated_at_utc: $generated_at_utc,
      label: $label,
      batch_dir: $batch_dir,
      models: [$model, $judge_model] | unique,
      model: $model,
      judge_model: $judge_model,
      evals_dir: $evals_dir,
      eval_search_dir: $eval_search_dir,
      runner: $runner,
      skills_total: $skills_total,
      skills_succeeded: $skills_succeeded,
      skills_failed: $skills_failed,
      runs: $runs
    }' > "$summary_file"

  printf '\nBatch summary:\n' >&2
  printf '  success: %s\n' "$skills_succeeded" >&2
  printf '  failed: %s\n' "$skills_failed" >&2
  printf '  summary: %s\n' "$summary_file" >&2
}

main "$@"
