---
name: mantle-network-primer
description: Use when users need Mantle fundamentals, developer onboarding context, or clarification of MNT gas, chain setup, inclusion, settlement, and finality.
---

# Mantle Network Primer

## Overview

This is a reference/onboarding skill for Mantle-specific concepts that are easy to misunderstand during development or user support. Explain stable Mantle concepts first, then use the reference for dated snapshots like chain settings, tooling links, and architecture notes. Avoid canned answers and label anything time-sensitive as a live-verify item.

## Role

- Treat this skill as domain-specific onboarding and misconception prevention, not as an execution operator.
- Use it to clarify Mantle-specific concepts, developer assumptions, and live-verify boundaries.
- Hand off address lookup, transaction risk, portfolio inspection, and execution planning to the specialized Mantle skills.

## Workflow

1. Classify the request as `basics`, `differences`, `operations`, or `live_verify`.
2. Load the matching section from `references/mantle-network-basics.md`:
   - `basics` -> core model and stable terminology
   - `differences` -> Mantle-specific differences and developer hints
   - `operations` -> network details, onboarding tools, RPC reliability, and source-of-truth links
   - `live_verify` -> use the reference only to frame what must be checked live
3. Respond in two layers when useful:
   - stable concept summary
   - dated snapshot details labeled with the reference date when operational specifics matter
4. For time-sensitive questions (fees, block time, throughput, current ecosystem status, or latest architecture rollout details), state that values can change and request live verification from official docs or tools.
5. When asked what makes Mantle different, focus on stable developer-relevant differences:
   - gas is paid in `MNT`
   - L2 inclusion is not the same as L1-backed settlement/finality
   - public RPC endpoints are rate-limited
   - Mantle-specific chain settings and onboarding links matter

## Response Rules

- Define key terms once: `sequencer`, `settlement`, `finality`, `gas token`.
- Distinguish transaction inclusion from final settlement.
- Use absolute dates for time-bound statements.
- Label snapshot values with the reference date when quoting them.
- Do not answer "latest/current" questions from this file alone.
- Avoid financial advice and price predictions.
- If confidence is low, say so directly and request a source check.

## References

- `references/mantle-network-basics.md`
