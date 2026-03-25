#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EVALS_DIR="$REPO_ROOT/evals"
EVAL_SPECS_DIR="$EVALS_DIR/specs"
RESULTS_DIR="$REPO_ROOT/evals/results"
JUDGE_PROMPT_FILE="$SCRIPT_DIR/judge.md"
YAML_BACKEND=""

BARE_SYSTEM_PROMPT="You are a helpful AI assistant."

usage() {
  cat <<'EOF'
Usage: ./evals/runner/run.sh --skill <slug-or-skill-name> --model <provider/model> [options]

Options:
  --skill <value>         Eval slug (for example: network-primer) or YAML skill name
  --model <value>         Target model in provider/model format (for example: openai/gpt-5.2 or openrouter/openai/gpt-5.2)
  --judge-model <value>   Judge model in provider/model format (defaults to --model)
  --output <path>         Write JSON report to this path instead of evals/results/<skill>-<timestamp>.json
  --skill-only            Only run the skill-loaded model (skip bare-model comparison)
  --list-skills           List available eval slugs and exit
  --help                  Show this help text

Environment:
  OPENAI_API_KEY          Required for provider=openai
  OPENAI_BASE_URL         Optional, defaults to https://api.openai.com/v1
  OPENROUTER_API_KEY      Required for provider=openrouter
  OPENROUTER_BASE_URL     Optional, defaults to https://openrouter.ai/api/v1
  OPENROUTER_HTTP_REFERER Optional attribution header for OpenRouter
  OPENROUTER_TITLE        Optional title header for OpenRouter
  JUDGE_JSON_RETRY_MAX_ATTEMPTS Optional, defaults to 3 (set 1 to disable)
  JUDGE_JSON_RETRY_BASE_DELAY_SECONDS Optional, defaults to 1
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

openai_responses_url() {
  local base_url="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
  if [[ "$base_url" == */responses ]]; then
    printf '%s\n' "$base_url"
  else
    printf '%s/responses\n' "${base_url%/}"
  fi
}

openai_input_json() {
  local developer_prompt="$1"
  local user_prompt="$2"

  jq -nc \
    --arg developer_prompt "$developer_prompt" \
    --arg user_prompt "$user_prompt" \
    '[
      {
        role: "system",
        content: [{ type: "input_text", text: $developer_prompt }]
      },
      {
        role: "user",
        content: [{ type: "input_text", text: $user_prompt }]
      }
    ]'
}

 

ensure_yaml_backend() {
  if command -v yq >/dev/null 2>&1; then
    YAML_BACKEND="yq"
    return
  fi

  require_cmd python3
  python3 - <<'PY' >/dev/null 2>&1 || die "python3 is available, but PyYAML is missing; install yq or PyYAML"
import yaml  # noqa: F401
PY
  YAML_BACKEND="python"
}

yaml_to_json() {
  local file_path="$1"
  python3 - "$file_path" <<'PY'
import json
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle)

json.dump(data, sys.stdout)
PY
}

yaml_raw_query() {
  local file_path="$1"
  local query="$2"

  if [[ "$YAML_BACKEND" == "yq" ]]; then
    yq -r "$query" "$file_path"
  else
    yaml_to_json "$file_path" | jq -r "$query"
  fi
}

yaml_json_query() {
  local file_path="$1"
  local query="$2"

  if [[ "$YAML_BACKEND" == "yq" ]]; then
    yq -o=json "$query" "$file_path"
  else
    yaml_to_json "$file_path" | jq -c "$query"
  fi
}

eval_search_dir() {
  if [[ -d "$EVAL_SPECS_DIR" ]]; then
    printf '%s\n' "$EVAL_SPECS_DIR"
  else
    printf '%s\n' "$EVALS_DIR"
  fi
}

list_skills() {
  local search_dir file
  search_dir=$(eval_search_dir)

  for file in "$search_dir"/*.yaml; do
    [[ -e "$file" ]] || continue
    basename "$file" .yaml
  done | sort
}

resolve_eval_file() {
  local requested="$1"
  local search_dir file skill_name legacy_basename
  search_dir=$(eval_search_dir)

  if [[ -f "$requested" ]]; then
    printf '%s\n' "$requested"
    return
  fi

  if [[ -f "$search_dir/$requested.yaml" ]]; then
    printf '%s\n' "$search_dir/$requested.yaml"
    return
  fi

  legacy_basename=$(basename "$requested")
  if [[ -f "$search_dir/$legacy_basename" ]]; then
    printf '%s\n' "$search_dir/$legacy_basename"
    return
  fi

  for file in "$search_dir"/*.yaml; do
    [[ -e "$file" ]] || continue
    skill_name=$(yaml_raw_query "$file" '.skill')
    if [[ "$skill_name" == "$requested" ]]; then
      printf '%s\n' "$file"
      return
    fi
  done

  die "could not resolve eval file for '$requested'"
}

extract_output_text() {
  jq -r '
    if (.output_text? // "") != "" then
      .output_text
    elif (.choices[0].message.content? // null) != null then
      if (.choices[0].message.content | type) == "string" then
        .choices[0].message.content
      else
        [
          .choices[0].message.content[]?
          | if (.text? // "") != "" then .text else empty end
        ] | join("")
      end
    else
      [
        .output[]?.content[]?
        | if (.text? // "") != "" then .text else empty end
      ] | join("")
    end
  '
}

provider_name() {
  local model_ref="$1"
  if [[ "$model_ref" == */* ]]; then
    printf '%s\n' "${model_ref%%/*}"
  else
    printf 'openai\n'
  fi
}

provider_model() {
  local model_ref="$1"
  if [[ "$model_ref" == */* ]]; then
    printf '%s\n' "${model_ref#*/}"
  else
    printf '%s\n' "$model_ref"
  fi
}

api_request_once() {
  local provider="$1"
  local endpoint="$2"
  local payload="$3"
  local base_url api_key request_url
  local -a curl_args

  case "$provider" in
    openai)
      api_key="${OPENAI_API_KEY:-}"
      [[ -n "$api_key" ]] || die "OPENAI_API_KEY is required for provider 'openai'"
      [[ "$endpoint" == "responses" ]] || die "unsupported endpoint '$endpoint' for provider 'openai'"
      request_url="$(openai_responses_url)"
      curl_args=(
        -sS -w '\n%{http_code}' "$request_url"
        -H "Authorization: Bearer $api_key"
        -H "Content-Type: application/json"
      )
      curl_args+=(-d "$payload")
      curl "${curl_args[@]}"
      ;;
    openrouter)
      api_key="${OPENROUTER_API_KEY:-}"
      [[ -n "$api_key" ]] || die "OPENROUTER_API_KEY is required for provider 'openrouter'"
      base_url="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
      [[ "$endpoint" == "chat/completions" ]] || die "unsupported endpoint '$endpoint' for provider 'openrouter'"

      curl_args=(
        -sS -w '\n%{http_code}' "${base_url%/}/chat/completions"
        -H "Authorization: Bearer $api_key"
        -H "Content-Type: application/json"
      )

      if [[ -n "${OPENROUTER_HTTP_REFERER:-}" ]]; then
        curl_args+=(-H "HTTP-Referer: ${OPENROUTER_HTTP_REFERER}")
      fi

      if [[ -n "${OPENROUTER_TITLE:-}" ]]; then
        curl_args+=(-H "X-Title: ${OPENROUTER_TITLE}")
      fi

      curl_args+=(-d "$payload")
      curl "${curl_args[@]}"
      ;;
    *)
      die "unsupported provider '$provider'; currently supported: openai, openrouter"
      ;;
  esac
}

api_request() {
  local provider="$1"
  local endpoint="$2"
  local payload="$3"
  local max_retries="${API_RETRY_MAX:-5}"
  local base_delay="${API_RETRY_BASE_DELAY:-10}"
  local attempt=0
  local response body http_code delay

  while true; do
    set +e
    response=$(api_request_once "$provider" "$endpoint" "$payload" 2>&1)
    local curl_exit=$?
    set -e

    if (( curl_exit != 0 )); then
      attempt=$((attempt + 1))
      if (( attempt > max_retries )); then
        printf 'api_request: curl failed after %d retries (exit %d)\n' "$max_retries" "$curl_exit" >&2
        return 1
      fi
      delay=$(( base_delay * (2 ** (attempt - 1)) ))
      printf 'api_request: curl error (exit %d), retry %d/%d in %ds\n' "$curl_exit" "$attempt" "$max_retries" "$delay" >&2
      sleep "$delay"
      continue
    fi

    http_code=$(printf '%s' "$response" | tail -n1)
    body=$(printf '%s' "$response" | sed '$d')

    if [[ "$http_code" == 2* ]]; then
      printf '%s\n' "$body"
      return 0
    elif [[ "$http_code" == "429" ]] || [[ "$http_code" == 5* ]]; then
      attempt=$((attempt + 1))
      if (( attempt > max_retries )); then
        printf 'api_request: HTTP %s after %d retries\n' "$http_code" "$max_retries" >&2
        return 1
      fi
      delay=$(( base_delay * (2 ** (attempt - 1)) ))
      printf 'api_request: HTTP %s, retry %d/%d in %ds\n' "$http_code" "$attempt" "$max_retries" "$delay" >&2
      sleep "$delay"
    else
      printf 'api_request: HTTP %s\n' "$http_code" >&2
      printf '%s\n' "$body" >&2
      return 1
    fi
  done
}

request_and_parse_judge_json() {
  local provider="$1"
  local endpoint="$2"
  local payload="$3"
  local max_attempts="${JUDGE_JSON_RETRY_MAX_ATTEMPTS:-3}"
  local base_delay="${JUDGE_JSON_RETRY_BASE_DELAY_SECONDS:-1}"
  local attempt=1
  local response=""
  local parsed=""
  local error_file=""
  local sleep_seconds=0

  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || (( max_attempts < 1 )); then
    max_attempts=1
  fi
  if ! [[ "$base_delay" =~ ^[0-9]+$ ]]; then
    base_delay=1
  fi

  while true; do
    if ! response=$(api_request "$provider" "$endpoint" "$payload"); then
      return 1
    fi

    error_file=$(mktemp)
    if parsed=$(printf '%s' "$response" | extract_output_text | jq -c . 2>"$error_file"); then
      rm -f "$error_file"
      printf '%s\n' "$parsed"
      return 0
    fi

    if (( attempt >= max_attempts )); then
      cat "$error_file" >&2
      rm -f "$error_file"
      return 1
    fi

    rm -f "$error_file"
    sleep_seconds=$(( base_delay * (2 ** (attempt - 1)) ))
    if (( sleep_seconds > 0 )); then
      sleep "$sleep_seconds"
    fi
    attempt=$((attempt + 1))
  done
}

judge_schema_json() {
  jq -nc '
    {
      type: "object",
      additionalProperties: false,
      properties: {
        verdict: {
          type: "string",
          enum: ["PASS", "PARTIAL", "FAIL"]
        },
        expected_hits: {
          type: "array",
          items: { type: "string" }
        },
        expected_misses: {
          type: "array",
          items: { type: "string" }
        },
        fail_triggers: {
          type: "array",
          items: { type: "string" }
        },
        reasoning: { type: "string" }
      },
      required: [
        "verdict",
        "expected_hits",
        "expected_misses",
        "fail_triggers",
        "reasoning"
      ]
    }'
}

chat_completion() {
  local model_ref="$1"
  local system_prompt="$2"
  local user_prompt="$3"
  local provider model_name payload input_json

  provider=$(provider_name "$model_ref")
  model_name=$(provider_model "$model_ref")

  case "$provider" in
    openai)
      input_json=$(openai_input_json "$system_prompt" "$user_prompt")
      payload=$(
        jq -n \
          --arg model "$model_name" \
          --argjson input "$input_json" \
          '{
            model: $model,
            temperature: 0,
            input: $input
          }'
      )
      api_request "$provider" "responses" "$payload" | extract_output_text
      ;;
    openrouter)
      payload=$(
        jq -n \
          --arg model "$model_name" \
          --arg system_prompt "$system_prompt" \
          --arg user_prompt "$user_prompt" \
          '{
            model: $model,
            temperature: 0,
            messages: [
              {
                role: "system",
                content: $system_prompt
              },
              {
                role: "user",
                content: $user_prompt
              }
            ]
          }'
      )
      api_request "$provider" "chat/completions" "$payload" | extract_output_text
      ;;
    *)
      die "unsupported provider '$provider'; currently supported: openai, openrouter"
      ;;
  esac
}

judge_answer() {
  local judge_model="$1"
  local judge_prompt="$2"
  local eval_prompt="$3"
  local answer="$4"
  local expected_json="$5"
  local fail_json="$6"
  local provider model_name payload schema_json judge_user_prompt input_json

  provider=$(provider_name "$judge_model")
  model_name=$(provider_model "$judge_model")
  schema_json=$(judge_schema_json)
  judge_user_prompt=$(
    jq -nr \
      --arg eval_prompt "$eval_prompt" \
      --arg answer "$answer" \
      --argjson expected_facts "$expected_json" \
      --argjson fail_if "$fail_json" \
      '"Prompt:\n" + $eval_prompt + "\n\n"
      + "Expected facts:\n" + ($expected_facts | tojson) + "\n\n"
      + "Fail conditions:\n" + ($fail_if | tojson) + "\n\n"
      + "Model answer:\n" + $answer'
  )

  case "$provider" in
    openai)
      input_json=$(openai_input_json "$judge_prompt" "$judge_user_prompt")
      payload=$(
        jq -n \
          --arg model "$model_name" \
          --argjson input "$input_json" \
          --argjson schema "$schema_json" \
          '{
            model: $model,
            temperature: 0,
            input: $input,
            text: {
              format: {
                type: "json_schema",
                name: "mantle_eval_judgment",
                strict: true,
                schema: $schema
              }
            }
          }'
      )
      request_and_parse_judge_json "$provider" "responses" "$payload"
      ;;
    openrouter)
      payload=$(
        jq -n \
          --arg model "$model_name" \
          --arg system_prompt "$judge_prompt" \
          --arg eval_prompt "$eval_prompt" \
          --arg answer "$answer" \
          --argjson expected_facts "$expected_json" \
          --argjson fail_if "$fail_json" \
          --argjson schema "$schema_json" \
          '{
            model: $model,
            temperature: 0,
            messages: [
              {
                role: "system",
                content: $system_prompt
              },
              {
                role: "user",
                content: (
                  "Prompt:\n" + $eval_prompt + "\n\n"
                  + "Expected facts:\n" + ($expected_facts | tojson) + "\n\n"
                  + "Fail conditions:\n" + ($fail_if | tojson) + "\n\n"
                  + "Model answer:\n" + $answer
                )
              }
            ],
            response_format: {
              type: "json_schema",
              json_schema: {
                name: "mantle_eval_judgment",
                strict: true,
                schema: $schema
              }
            }
          }'
      )
      request_and_parse_judge_json "$provider" "chat/completions" "$payload"
      ;;
    *)
      die "unsupported provider '$provider'; currently supported: openai, openrouter"
      ;;
  esac
}

build_skill_system_prompt() {
  local bundled_reference="$1"
  cat <<EOF
You are a helpful AI assistant specializing in the Mantle network ecosystem.
Use the following reference material to answer the question.

--- REFERENCE ---
$bundled_reference
--- END REFERENCE ---
EOF
}

verdict_score() {
  case "$1" in
    PASS) printf '2\n' ;;
    PARTIAL) printf '1\n' ;;
    FAIL) printf '0\n' ;;
    *) printf '%s\n' '-1' ;;
  esac
}

compare_verdicts() {
  local bare_verdict="$1"
  local skill_verdict="$2"
  local bare_score skill_score

  bare_score=$(verdict_score "$bare_verdict")
  skill_score=$(verdict_score "$skill_verdict")

  if (( skill_score > bare_score )); then
    printf 'skill_better\n'
  elif (( skill_score < bare_score )); then
    printf 'bare_better\n'
  else
    printf 'same\n'
  fi
}

main() {
  local skill_arg=""
  local model=""
  local judge_model=""
  local output_path=""
  local list_only=0
  local skill_only=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skill)
        [[ $# -ge 2 ]] || die "--skill requires a value"
        skill_arg="$2"
        shift 2
        ;;
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
      --output)
        [[ $# -ge 2 ]] || die "--output requires a value"
        output_path="$2"
        shift 2
        ;;
      --skill-only)
        skill_only=1
        shift
        ;;
      --list-skills)
        list_only=1
        shift
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

  if (( list_only == 1 )); then
    list_skills
    exit 0
  fi

  require_cmd curl
  require_cmd jq
  ensure_yaml_backend

  [[ -n "$skill_arg" ]] || die "--skill is required"
  [[ -n "$model" ]] || die "--model is required"
  [[ -f "$JUDGE_PROMPT_FILE" ]] || die "missing judge prompt: $JUDGE_PROMPT_FILE"

  judge_model="${judge_model:-$model}"
  mkdir -p "$RESULTS_DIR"

  local eval_file eval_slug skill_name skill_path description bundled_reference reference_paths_json
  local -a reference_paths=()
  eval_file=$(resolve_eval_file "$skill_arg")
  eval_slug=$(basename "$eval_file" .yaml)
  skill_name=$(yaml_raw_query "$eval_file" '.skill')
  skill_path=$(yaml_raw_query "$eval_file" '.skill_path')
  description=$(yaml_raw_query "$eval_file" '.description')
  while IFS= read -r line; do
    reference_paths+=("$line")
  done < <(yaml_raw_query "$eval_file" '.reference_paths[]?')

  if (( ${#reference_paths[@]} > 0 )); then
    bundled_reference=$("$SCRIPT_DIR/load-skill.sh" "$skill_path" "${reference_paths[@]}")
    reference_paths_json=$(printf '%s\n' "${reference_paths[@]}" | jq -R . | jq -s .)
  else
    bundled_reference=$("$SCRIPT_DIR/load-skill.sh" "$skill_path")
    reference_paths_json='[]'
  fi

  local skill_system_prompt judge_prompt timestamp output_file
  skill_system_prompt=$(build_skill_system_prompt "$bundled_reference")
  judge_prompt=$(cat "$JUDGE_PROMPT_FILE")
  timestamp=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
  output_file="${output_path:-$RESULTS_DIR/${eval_slug}-${timestamp}.json}"

  local eval_count tmpdir result_lines_file
  eval_count=$(yaml_raw_query "$eval_file" '.evals | length')
  tmpdir=$(mktemp -d)
  result_lines_file="$tmpdir/results.jsonl"
  trap "rm -rf '$tmpdir'" EXIT

  printf 'Running %s eval(s) for %s with %s (judge: %s)\n' \
    "$eval_count" "$eval_slug" "$model" "$judge_model" >&2

  local index eval_json eval_id prompt bare_answer skill_answer bare_judge skill_judge
  local expected_json fail_json bare_verdict skill_verdict comparison

  for (( index = 0; index < eval_count; index++ )); do
    eval_json=$(yaml_json_query "$eval_file" ".evals[$index]")
    eval_id=$(jq -r '.id' <<<"$eval_json")
    prompt=$(jq -r '.prompt' <<<"$eval_json")
    expected_json=$(jq -c '.expected_facts' <<<"$eval_json")
    fail_json=$(jq -c '.fail_if' <<<"$eval_json")

    skill_answer=$(chat_completion "$model" "$skill_system_prompt" "$prompt")
    skill_judge=$(judge_answer "$judge_model" "$judge_prompt" "$prompt" "$skill_answer" "$expected_json" "$fail_json")
    skill_verdict=$(jq -r '.verdict' <<<"$skill_judge")

    if (( skill_only == 1 )); then
      bare_answer=""
      bare_judge='{"verdict":"SKIPPED","expected_hits":[],"expected_misses":[],"fail_triggers":[],"reasoning":"bare model skipped (--skill-only)"}'
      bare_verdict="SKIPPED"
      comparison="skill_only"
    else
      bare_answer=$(chat_completion "$model" "$BARE_SYSTEM_PROMPT" "$prompt")
      bare_judge=$(judge_answer "$judge_model" "$judge_prompt" "$prompt" "$bare_answer" "$expected_json" "$fail_json")
      bare_verdict=$(jq -r '.verdict' <<<"$bare_judge")
      comparison=$(compare_verdicts "$bare_verdict" "$skill_verdict")
    fi

    jq -n \
      --argjson eval_case "$eval_json" \
      --arg bare_answer "$bare_answer" \
      --arg skill_answer "$skill_answer" \
      --argjson bare_judgment "$bare_judge" \
      --argjson skill_judgment "$skill_judge" \
      --arg comparison "$comparison" \
      '$eval_case + {
        bare_answer: $bare_answer,
        skill_answer: $skill_answer,
        bare_judgment: $bare_judgment,
        skill_judgment: $skill_judgment,
        comparison: $comparison
      }' >> "$result_lines_file"

    printf '[%d/%d] %s bare=%s skill=%s (%s)\n' \
      "$((index + 1))" "$eval_count" "$eval_id" "$bare_verdict" "$skill_verdict" "$comparison" >&2
  done

  local results_json summary_json report_json
  results_json=$(jq -s '.' "$result_lines_file")
  summary_json=$(
    jq -n \
      --argjson results "$results_json" '
        def score(v):
          if v == "PASS" then 2
          elif v == "PARTIAL" then 1
          elif v == "FAIL" then 0
          else -1 end;
        def verdict_counts(key):
          reduce ($results[] | .[key].verdict) as $verdict (
            {PASS: 0, PARTIAL: 0, FAIL: 0};
            .[$verdict] += 1
          );
        {
          eval_count: ($results | length),
          bare: verdict_counts("bare_judgment"),
          skill: verdict_counts("skill_judgment"),
          skill_better: ($results | map(select(score(.skill_judgment.verdict) > score(.bare_judgment.verdict))) | length),
          bare_better: ($results | map(select(score(.skill_judgment.verdict) < score(.bare_judgment.verdict))) | length),
          same: ($results | map(select(score(.skill_judgment.verdict) == score(.bare_judgment.verdict))) | length)
        }'
  )

  report_json=$(
    jq -n \
      --arg generated_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg model "$model" \
      --arg judge_model "$judge_model" \
      --arg eval_slug "$eval_slug" \
      --arg eval_file "${eval_file#$REPO_ROOT/}" \
      --arg skill "$skill_name" \
      --arg skill_path "$skill_path" \
      --arg description "$description" \
      --argjson reference_paths "$reference_paths_json" \
      --argjson summary "$summary_json" \
      --argjson results "$results_json" \
      '{
        generated_at_utc: $generated_at_utc,
        model: $model,
        judge_model: $judge_model,
        eval_slug: $eval_slug,
        eval_file: $eval_file,
        skill: $skill,
        skill_path: $skill_path,
        reference_paths: $reference_paths,
        description: $description,
        summary: $summary,
        results: $results
      }'
  )

  printf '%s\n' "$report_json" > "$output_file"

  printf '\nSummary:\n' >&2
  jq -r '
    [
      "  bare  PASS/PARTIAL/FAIL: \(.bare.PASS)/\(.bare.PARTIAL)/\(.bare.FAIL)",
      "  skill PASS/PARTIAL/FAIL: \(.skill.PASS)/\(.skill.PARTIAL)/\(.skill.FAIL)",
      "  comparison skill_better/same/bare_better: \(.skill_better)/\(.same)/\(.bare_better)"
    ] | .[]
  ' <<<"$summary_json" >&2
  printf 'Results written to %s\n' "$output_file" >&2
}

main "$@"
