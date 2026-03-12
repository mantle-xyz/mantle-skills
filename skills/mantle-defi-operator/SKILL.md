---
name: mantle-defi-operator
description: Use when a Mantle DeFi task needs discovery, venue comparison, or execution-ready planning with verified contracts, preflight evidence, and an external handoff.
---

# Mantle Defi Operator

## Overview

Coordinate deterministic pre-execution planning for Mantle DeFi intents. This skill should orchestrate verified address lookup, preflight evidence, and execution handoff steps instead of duplicating specialized address, risk, or portfolio analysis.

## When Not to Use

- Use `mantle-address-registry-navigator` when the task is only address lookup, whitelist validation, or anti-phishing review.
- Use `$mantle-risk-evaluator` when the task is only to return a `pass` / `warn` / `block` preflight verdict.
- Use `$mantle-portfolio-analyst` when the task is only balance coverage, allowance exposure, or spender-risk review.
- Stay in `discovery_only` mode when the user is exploring venues and has not asked for execution-ready planning.

## Quick Checklist

- `discovery_only`
  - Return venue suggestions, rationale, and discovery sources only.
  - Do not return router addresses, approval steps, calldata, or sequencing.
  - Set `handoff_available` to `no`.
- `compare_only`
  - Compare verified venues and call out missing execution inputs.
  - Allow verified registry keys or contract roles, but stop short of approval instructions or calldata.
  - Leave `risk_report_ref` / `portfolio_report_ref` empty or explicitly missing when evidence is not available.
  - Set `handoff_available` to `no`.
- `execution_ready`
  - Require `address_resolution_ref`.
  - Require `risk_report_ref` unless explicitly unnecessary for the operation.
  - Require `portfolio_report_ref` when allowance scope or balance coverage matters, or explain why it is unnecessary.
  - Only then expose approval planning, sequencing, calldata, and `handoff_available: yes`.

## Workflow

1. Normalize intent:
   - `swap`, `add_liquidity`, `remove_liquidity`, or compound flow
   - token addresses, amounts, recipient, deadline, slippage
2. Run prep checks from `references/defi-execution-guardrails.md`.
3. Resolve candidate protocol contracts from `mantle-address-registry-navigator` using the required registry key or protocol role for the requested action.
4. Classify the planning mode:
   - `execution_ready`: verified addresses plus enough quote/risk evidence to produce a handoff
   - `compare_only`: venue comparison is possible, but execution gating is incomplete
   - `discovery_only`: high-level ecosystem exploration without execution readiness
5. Build the candidate set from `references/curated-defaults.yaml`; carry forward each default's freshness metadata and rationale, and if the user names another protocol, keep it `compare_only` until its contracts are verified.
6. Rank only eligible candidates with live signals from `references/protocol-selection-policy.md`:
   - swaps: quote quality, recent volume, pool depth, slippage risk
   - liquidity: TVL, recent volume, pool fit, operational complexity
   - lending: TVL, utilization, asset support, withdrawal liquidity
   - if live metrics are stale or unavailable, fall back to curated defaults and say so explicitly
   - if only one curated, verified candidate fits the requested action, recommend it first before asking optimization follow-ups
7. Pull supporting evidence before execution planning:
   - address trust from `mantle-address-registry-navigator`
   - preflight verdict from `$mantle-risk-evaluator` when a state-changing path is being prepared
   - allowance and spend-capacity context from `$mantle-portfolio-analyst` when approval scope or wallet coverage matters
8. Structure the result per `planning_mode` using the `Quick Checklist`:
   - `recommended`
   - `also_viable`
   - `discovery_only`
   - mention `DefiLlama` only for broader ecosystem discovery, never as contract truth
9. Load operation SOP only for `execution_ready` planning:
   - swap: `references/swap-sop.md`
   - liquidity: `references/liquidity-sop.md`
10. Resolve quote, pool, or market route only after the protocol choice is gated by verified contracts and supporting evidence.
11. If an approval is required, carry forward the allowance evidence and prepare the smallest viable `approve` step.
12. If account supports batching (for example ERC-4337 smart account), note whether approve+action can be safely batched by the external executor.
13. Produce an execution handoff plan (calls, parameters, sequencing, and risk notes). Do not sign, broadcast, deploy, or claim execution.
14. Define post-execution verification checks (balances, allowances, slippage) to run after the user confirms external execution.

## Guardrails

- This skill is read-only with mantle-mcp v0.2: never claim signed/broadcast/deployed/executed transactions.
- Act as a coordinator: when specialized address, risk, or portfolio skills apply, cite or request their output instead of re-deriving those judgments from scratch.
- In `discovery_only`, do not provide router addresses, approval steps, calldata, or execution sequencing.
- In `compare_only`, verified registry keys or contract roles may be named, but executable calldata and approval instructions stay out until execution evidence is complete.
- Do not proceed to external execution planning on `warn`/`high-risk` intents without explicit user confirmation.
- Reject unknown or unverified token/router/pool addresses.
- Never treat discovery data as a substitute for a verified registry key.
- If the required contract role cannot be resolved from the shared registry, mark the plan `blocked`.
- Mention discovery-only protocols only after clearly separating them from execution-ready options.
- Keep per-step idempotency notes for external retries.
- If the user asks for onchain execution, provide a handoff checklist and state that an external signer/wallet is required.

## Output Format

```text
Mantle DeFi Pre-Execution Report
- operation_type:
- planning_mode: discovery_only | compare_only | execution_ready
- environment:
- intent_summary:
- analyzed_at_utc:

Preparation
- supporting_skills_used:
- address_resolution_ref:
- risk_report_ref:
- portfolio_report_ref:
- curated_defaults_considered:
- quote_source:
- expected_output_min:
- allowance_status:
- approval_plan:

Protocol Selection
- recommended:
- also_viable:
- discovery_only:
- rationale:
- data_freshness:
- confidence: high | medium | low

Execution Handoff
- recommended_calls:
- calldata_inputs:
- registry_key:
- sequencing_notes:
- batched_execution_possible: yes | no
- handoff_available: yes | no

Post-Execution Verification Plan
- balances_to_recheck:
- allowances_to_recheck:
- slippage_checks:
- anomalies_to_watch:

Status
- preflight_verdict: pass | warn | block | unknown
- readiness: ready | blocked | needs_input
- blocking_issues:
- next_action:
```

## References

- `references/defi-execution-guardrails.md`
- `references/swap-sop.md`
- `references/liquidity-sop.md`
- `references/curated-defaults.yaml`
- `references/protocol-selection-policy.md`
