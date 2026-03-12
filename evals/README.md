# Evals

`evals/` contains the in-repo evaluation harness for measuring whether loading a Mantle skill improves model behavior relative to the bare model on the same prompt set.

## Layout

- `evals/specs/*.yaml`: per-skill eval suites with prompts, `expected_facts`, and `fail_if` checks
- `evals/runner/run.sh`: main CLI for single-skill A/B runs
- `evals/runner/load-skill.sh`: bundles `SKILL.md` plus local references and assets into prompt context
- `evals/runner/judge.md`: grading prompt used to score answers
- `evals/results/`: checked-in summaries plus generated batch outputs

## Requirements

- `bash`, `curl`, `jq`, and either `yq` or `python3` with PyYAML
- `OPENAI_API_KEY` for `openai/*` models or `OPENROUTER_API_KEY` for `openrouter/*` models
- a model string in `provider/model` format such as `openai/gpt-5.4` or `openrouter/openai/gpt-5.4`

## Run an Eval

```bash
./evals/runner/run.sh --skill network-primer --model openai/gpt-5.4
```

```bash
./evals/runner/run.sh --skill network-primer --model openrouter/openai/gpt-5.4
```

The runner writes a JSON report under `evals/results/` with bare-model answers, skill-loaded answers, judged verdicts, and comparison counts.

## Current Checked-In Results

The repository currently includes full-suite runs from March 11, 2026 to March 12, 2026 covering 71 evals across 10 skills.

| Model | With skill | Without skill | Uplift | Comparison |
| --- | --- | --- | --- | --- |
| `openrouter/arcee-ai/trinity-large-preview:free` | 97.2% pass (69 pass, 0 partial, 2 fail) | 29.6% pass (21 pass, 5 partial, 45 fail) | +67.6 pts | 48 `skill_better`, 23 `same`, 0 `bare_better` |
| `openai/gpt-5.4` | 93.0% pass (66 pass, 5 partial, 0 fail) | 28.2% pass (20 pass, 15 partial, 36 fail) | +64.8 pts | 50 `skill_better`, 20 `same`, 1 `bare_better` |

Detailed per-skill breakdowns, raw batch links, and notes live in [`evals/results/RESULT.md`](./results/RESULT.md).
