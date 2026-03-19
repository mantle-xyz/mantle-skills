---
name: mantle-bridge-operator
description: Use when a task involves bridging assets between Ethereum L1 and Mantle L2, checking bridge status, estimating bridge costs, or planning cross-layer operations.
---

# Mantle Bridge Operator

## Overview

Coordinate read-only bridge analysis and external execution planning for Mantle L1-L2 asset transfers. This skill covers deposit readiness checks, withdrawal status tracking, fee estimation, and third-party bridge comparison — without executing any transactions.

## When Not to Use

- Use `mantle-portfolio-analyst` when the task is only balance or allowance inspection on a single layer.
- Use `mantle-risk-evaluator` when the task is only a preflight risk verdict for a non-bridge transaction.
- Use `mantle-defi-operator` when the task is DeFi execution planning within Mantle L2 only.

## Workflow

1. Classify the bridge intent:
   - `deposit`: L1 (Ethereum) to L2 (Mantle)
   - `withdrawal`: L2 (Mantle) to L1 (Ethereum)
   - `status_check`: track an in-progress bridge operation
   - `comparison`: compare native bridge vs third-party options
2. Resolve asset details:
   - Use `mantle_resolveToken` to verify token addresses on both layers.
   - Use `mantle_getTokenInfo` for decimals and symbol confirmation.
   - Check `references/bridge-token-mappings.md` for L1-L2 address pairs.
3. Verify pre-bridge state:
   - `mantle_getBalance` for native MNT/ETH balances on the source chain.
   - `mantle_getTokenBalances` for ERC-20 balances on the source chain.
   - `mantle_getAllowances` to check if bridge contract has sufficient approval (deposits only).
4. Estimate costs from `references/bridge-fee-guide.md`:
   - Native bridge: gas-only, no protocol fee.
   - L1 to L2: ETH gas on Ethereum (~$5-50 depending on congestion).
   - L2 to L1: MNT gas on L2 (initiate) + ETH gas on L1 (prove + finalize).
5. For withdrawals, determine the current phase:
   - `initiated`: waiting for state root proposal (~60 minutes).
   - `ready_to_prove`: user must submit proof on L1.
   - `in_challenge_period`: 12-hour execution delay (ZK validity proof).
   - `ready_to_finalize`: user must submit finalization on L1.
   - `finalized`: complete.
6. For comparison mode, evaluate options from `references/third-party-bridges.md`:
   - Speed vs cost tradeoff.
   - Native bridge (free, slow) vs third-party (fee, fast).
   - Only recommend bridges with verified Mantle support.
7. Check network health:
   - `mantle_getChainStatus` for L2 block production.
   - `mantle_checkRpcHealth` if endpoint issues are suspected.
8. Produce a bridge report per the output format below.
9. If the user wants to execute, provide an external handoff checklist:
   - Contract address, function signature, parameters.
   - Required gas token on each chain.
   - Link to official bridge UI: `https://app.mantle.xyz/bridge`.

## Guardrails

- This skill is read-only with mantle-mcp v0.1: never claim to have executed, signed, or broadcast a bridge transaction.
- Never fabricate bridge transaction status. If status cannot be determined from available tools, say so.
- Always verify token addresses on both L1 and L2 before recommending a bridge operation.
- Warn about the 12-hour execution delay for L2 to L1 withdrawals (ZK validity proof mode).
- Warn about unsupported token types: fee-on-transfer tokens and rebasing tokens are NOT compatible with the Standard Bridge.
- For first-time users depositing to Mantle, note they will need MNT for gas. Mantle provides 1 MNT to new wallets on first deposit.
- Do not recommend third-party bridges without noting they are not part of the Mantle native bridge and carry their own trust assumptions.
- If a user asks about stuck funds, guide them through the withdrawal phases — do not suggest workarounds that bypass the challenge period.

## Output Format

```text
Mantle Bridge Report
- operation: deposit | withdrawal | status_check | comparison
- direction: L1_to_L2 | L2_to_L1
- environment: mainnet | sepolia
- asset:
- amount:
- analyzed_at_utc:

Source Chain State
- chain: Ethereum L1 | Mantle L2
- native_balance:
- token_balance:
- bridge_allowance: sufficient | insufficient | not_required

Cost Estimate
- bridge_fee: none (native) | <amount> (<bridge_name>)
- gas_estimate_source: <gas_token> <amount>
- gas_estimate_destination: <gas_token> <amount>
- total_estimated_cost_usd:

Withdrawal Status (L2 to L1 only)
- phase: initiated | ready_to_prove | in_challenge_period | ready_to_finalize | finalized | unknown
- time_remaining:
- next_action:

Bridge Comparison (comparison mode only)
- native_bridge:
  speed:
  cost:
  trust: canonical
- alternatives:
  - name:
    speed:
    cost:
    trust: third_party

Execution Handoff
- contract:
- function:
- parameters:
- gas_token_required:
- bridge_ui: https://app.mantle.xyz/bridge
- handoff_available: yes | no

Status
- readiness: ready | blocked | needs_input
- blocking_issues:
- warnings:
- next_action:
```

## References

- `references/bridge-fee-guide.md`
- `references/bridge-token-mappings.md`
- `references/third-party-bridges.md`
