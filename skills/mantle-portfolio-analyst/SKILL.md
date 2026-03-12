---
name: mantle-portfolio-analyst
description: Use when a Mantle task needs wallet balances, token holdings, allowance exposure, or unlimited-approval review before a DeFi or security decision.
---

# Mantle Portfolio Analyst

## Overview

Build deterministic, read-only wallet analysis on Mantle. Enumerate balances and allowances, then highlight approval risk in a structured report.

## Workflow

1. Confirm inputs:
   - `wallet_address`
   - `network` (`mainnet` or `sepolia`)
   - optional token/spender scope
2. Validate requested wallet and chain context:
   - `mantle_validateAddress`
   - `mantle_getChainInfo`
   - `mantle_getChainStatus`
3. Determine analysis scope:
   - token list from user input or `mantle://registry/tokens`
   - spender list from user input or `mantle://registry/protocols`
4. Fetch native balance with `mantle_getBalance`.
5. Fetch ERC-20 balances with `mantle_getTokenBalances`.
6. Fetch token-spender allowances with `mantle_getAllowances`.
7. If a token's metadata is missing, use `mantle_getTokenInfo` for that token and keep missing fields as `unknown` when unresolved.
8. Classify approval risk with `references/allowance-risk-rules.md`.
9. Return a formatted report with findings, confidence, and explicit coverage/partial gaps.

## Guardrails

- Use mantle-mcp v0.2 read-only tools only for this skill (`mantle_getBalance`, `mantle_getTokenBalances`, `mantle_getAllowances`, `mantle_getTokenInfo`, chain/address validation helpers).
- Stay read-only; do not construct or send transactions.
- Do not reference direct JSON-RPC calls (`eth_*`) as if they are callable tools in this workflow.
- Do not guess token decimals or symbols if calls fail.
- Validate checksummed addresses for wallet, token, and spender.
- Mark missing token metadata as `unknown` and continue.
- If RPC responses are inconsistent, report partial coverage explicitly.

## Report Format

```text
Mantle Portfolio Report
- wallet:
- network:
- chain_id:
- collected_at_utc:

Native Balance
- MNT:

Token Balances
- token: <symbol_or_label>
  address:
  balance_raw:
  decimals:
  balance_normalized:

Allowance Exposure
- token:
  spender:
  allowance_raw:
  allowance_normalized:
  risk_level: low | medium | high | critical
  rationale:

Summary
- tokens_with_balance:
- allowances_checked:
- unlimited_or_near_unlimited_count:
- key_risks:
- confidence:
```

## References

- `references/rpc-readonly-workflow.md`
- `references/allowance-risk-rules.md`
