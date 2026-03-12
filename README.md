# Mantle Skills

Mantle-focused filesystem skills plus an in-repo eval harness for measuring whether those skills improve model behavior on Mantle-specific tasks.

## Start Here

- [`skills/README.md`](skills/README.md) for the skill catalog, categories, and directory conventions
- [`evals/README.md`](evals/README.md) for the eval harness, how to run it, and summary results
- [`evals/results/RESULT.md`](evals/results/RESULT.md) for the detailed per-skill eval report
- [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution expectations
- [`SECURITY.md`](SECURITY.md) for sensitive issue reporting guidance

## Repository Layout

- `skills/` contains the Mantle skill directories, each centered on a `SKILL.md`
- `evals/specs/*.yaml` defines per-skill eval suites
- `evals/runner/` contains the bash runner and prompt-loading scripts
- `evals/results/` stores checked-in summaries and generated batch outputs

## Quick Use

1. Open the target skill's `SKILL.md`.
2. Load only the `references/` or `assets/` files needed for the task.
3. Run `./evals/runner/run.sh --skill <slug> --model <provider/model>` to compare bare vs skill-loaded behavior.
