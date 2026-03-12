---
name: mantle-risk-evaluator
description: Use when a Mantle state-changing intent needs pre-execution slippage, liquidity, address-safety, allowance-scope, or gas/deadline checks.
---

# Mantle Risk Evaluator

## Overview

Run a mandatory pre-flight checklist and return a clear `pass`, `warn`, or `block` verdict. Prevent unsafe execution when any critical condition fails.

## Workflow

1. Normalize intent input:
   - operation type
   - token in/out and amount
   - target protocol/router/pool addresses
   - user risk parameters (slippage cap, deadline, max gas preference)
2. Execute checklist from `references/risk-checklist.md`.
3. Apply thresholds in `references/risk-threshold-guidance.md`.
4. Classify each item:
   - `pass`
   - `warn`
   - `fail`
5. Produce final verdict:
   - `pass`: no fails, optional warns.
   - `warn`: no critical fails, but user confirmation required.
   - `block`: one or more critical fails.

## Blocking Conditions

- Planned slippage exceeds user cap.
- Address risk check fails (unknown or flagged counterparty).
- Liquidity depth indicates severe price impact beyond threshold.
- Mandatory intent field is missing (cannot evaluate safely).

## Output Format

```text
Mantle Preflight Risk Report
- operation:
- environment:
- evaluated_at_utc:

Checklist
- slippage_check: pass | warn | fail
  details:
- liquidity_depth_check: pass | warn | fail
  details:
- address_safety_check: pass | warn | fail
  details:
- allowance_scope_check: pass | warn | fail
  details:
- gas_and_deadline_check: pass | warn | fail
  details:

Final Verdict
- status: pass | warn | block
- blocking_reasons:
- user_action_required:
```

## References

- `references/risk-checklist.md`
- `references/risk-threshold-guidance.md`
