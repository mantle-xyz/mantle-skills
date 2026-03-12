---
name: mantle-tx-simulator
description: Use when a Mantle transaction needs pre-signing simulation evidence, state-diff review, revert analysis, or a WYSIWYS explanation before execution.
---

# Mantle Tx Simulator

## Overview

Prepare simulation handoff packages for external backends and translate returned technical diffs into user-readable expected outcomes before signing or execution.

## Workflow

1. Normalize simulation request:
   - network
   - from/to/value/data
   - optional bundle/multicall context
2. Select an external simulation backend using `references/simulation-backends.md`.
3. Capture pre-state:
   - relevant token balances
   - allowance values
   - nonce and gas context
4. Produce an external simulation handoff package:
   - tx payload and network
   - required pre-state context
   - requested outputs (status/gas/logs/diffs)
5. After external execution evidence is provided, collect:
   - success/revert
   - gas estimate
   - logs/events
   - state diffs
6. Convert technical result into WYSIWYS summary with `references/wysiwys-template.md`.
7. If simulation evidence is missing, fails, or confidence is low, return `do_not_execute`.

## Guardrails

- This skill is read-only with mantle-mcp v0.2: it cannot execute transaction simulations directly.
- Never broadcast real transactions from this skill.
- Never claim a simulation has run unless external backend output is provided.
- Distinguish simulated estimate from guaranteed execution result.
- If token decimals/pricing context is incomplete, state uncertainty explicitly.
- For bundle flows, describe each step and net effect.
- If asked to run simulation via MCP tool, explain v0.2 has no tx simulation execution tool and provide external handoff instructions.

## Output Format

```text
Mantle Simulation Report
- execution_mode: external_simulator_handoff
- backend:
- environment:
- simulated_at_utc: <external timestamp if available>
- status: pending_external_simulation | success | revert | inconclusive
- simulation_artifact: <external link/id if available>

State Diff Summary
- assets_debited:
- assets_credited:
- approvals_changed:
- contract_state_changes:

Execution Estimates
- gas_estimate:
- estimated_fee_native:
- slippage_or_price_impact_note:

WYSIWYS
- plain_language_outcome:
- what_user_gives:
- what_user_gets_min:
- do_not_execute_reason: <empty if safe>
```

## References

- `references/simulation-backends.md`
- `references/wysiwys-template.md`
