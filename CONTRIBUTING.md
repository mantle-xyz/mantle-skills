# Contributing

Thanks for contributing to `mantle-skills`.

## Scope

This repository contains:

- Mantle-focused filesystem skills under `skills/`
- Eval definitions under `evals/specs/*.yaml`
- Eval runner scripts under `evals/runner/`
- Checked-in eval summaries under `evals/results/`

Keep changes narrowly scoped. Do not mix unrelated skill edits, eval changes, and runner refactors in one patch unless they are directly coupled.

## Contribution Guidelines

- Follow the repository [Code of Conduct](./CODE_OF_CONDUCT.md).
- Prefer small pull requests with a clear purpose.
- Update the relevant README when repository structure or usage changes.
- Keep skill behavior deterministic and fail-closed when verification is missing.
- Do not add guessed addresses, fabricated endpoints, or unverifiable operational claims.
- Do not commit secrets, private keys, API keys, wallet seeds, or local machine paths.
- Avoid committing generated logs or scratch outputs.

## Skill Changes

When editing a skill:

- Update `SKILL.md` first.
- Change only the `references/` or `assets/` files needed for that behavior.
- Keep boundaries between skills clear; prefer specialized skills over broad duplication.
- Preserve the repository's read-only and external-execution guardrails where applicable.

## Eval Changes

When editing evals:

- Keep prompts concrete and scoped to one behavior.
- Use `expected_facts` for required truths and `fail_if` for crisp failure conditions.
- Prefer evals that distinguish skill-specific uplift from generic model competence.
- Update [`evals/results/RESULT.md`](./evals/results/RESULT.md) only when checked-in result summaries need to change.

## Verification

Before submitting:

- Run `git diff --check`
- Run the offline smoke tests in `evals/runner/tests/`
- If you changed runner behavior, re-run the relevant smoke tests and inspect their output
- If you changed checked-in documentation, verify links and paths from the repository root

## Pull Request Notes

A good pull request includes:

- what changed
- why it changed
- how it was verified
- any follow-up work intentionally left out
