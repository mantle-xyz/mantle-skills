---
name: mantle-portfolio-analyst
description: Use when a Mantle task needs wallet balances, token holdings, DeFi positions (Aave, LP), allowance exposure, or unlimited-approval review before a DeFi or security decision.
---

# Mantle Portfolio Analyst

## Overview

Build deterministic, read-only wallet analysis on Mantle. Enumerate balances, DeFi positions (Aave V3 lending, V3 LP, Merchant Moe LB LP), and allowances, then highlight approval risk in a structured report.

## Workflow

1. Confirm inputs:
   - `wallet_address`
   - `network` (`mainnet` or `sepolia`)
   - optional token/spender scope
2. Validate requested wallet and chain context:
   - `mantle-cli registry validate <address> --json`
   - `mantle-cli chain info --json`
   - `mantle-cli chain status --json`
3. Determine analysis scope:
   - token list from user input or `mantle://registry/tokens`
   - spender list from user input or `mantle://registry/protocols`
4. Fetch native balance with `mantle-cli account balance <address> --json`.
5. Fetch ERC-20 balances with `mantle-cli account token-balances <address> --tokens <list> --json`.
6. Fetch Aave V3 positions with `mantle-cli aave positions --user <address> --json`.
   - This returns aggregate account data (total collateral/debt USD, health factor) and per-reserve supplied/borrowed amounts.
   - aToken balances are **positive assets** (collateral), debtToken balances are **liabilities** (debt).
   - Include health_status in the report. Flag `at_risk` or `liquidatable` positions prominently.
7. Fetch V3 LP positions with `mantle-cli lp positions --owner <address> --json`.
   - Returns positions across Agni and Fluxion DEXes with tick ranges, liquidity, and in-range status.
   - Include as LP assets in the portfolio.
8. Fetch Merchant Moe LB positions with `mantle-cli lp lb-positions --owner <address> --json`.
   - Returns LB bin positions with user share percentage and estimated token amounts.
   - Include as LP assets in the portfolio.
9. Fetch token-spender allowances with `mantle-cli account allowances <owner> --pairs <token:spender,...> --json`.
10. If a token's metadata is missing, use `mantle-cli token info <token> --json` for that token and keep missing fields as `unknown` when unresolved.
11. Classify approval risk using these rules:
   - `low`: allowance is zero, or tightly bounded and clearly below wallet balance/expected use.
   - `medium`: allowance is non-zero and larger than immediate expected use, but still bounded.
   - `high`: allowance is very large relative to expected use, or intentionally broad with unclear user intent.
   - `critical`: `is_unlimited=true` from tool output, or allowance equals/near-max integer (value >= 2^255).
   - Always include a rationale sentence with each risk label.
   - Mark spender trust as `unknown` unless verified from `mantle://registry/protocols` or user-confirmed.
   - Highlight all `high` and `critical` approvals at top of summary.
   - If token decimals are missing, classify using raw value and downgrade confidence.
12. Handle partial results from DeFi position tools:
   - If `mantle-cli aave positions` returns `partial: true`, note which reserves had errors and state that per-reserve breakdowns may be incomplete while aggregate USD totals (from `getUserAccountData`) remain accurate.
   - If `mantle-cli aave positions` returns `possible_missing_reserves: true`, warn that Aave governance may have added new reserves not yet tracked by this tool. Aggregate USD totals are still accurate.
   - Check each position's `collateral_enabled` field. If any position has `supplied > 0` but `collateral_enabled: false`, flag it as a **collateral warning** — the user has deposited tokens but they are NOT counting toward borrowing capacity. This can cause borrow failures.
   - If `mantle-cli lp lb-positions` returns positions, note the `coverage: "known_pairs_only"` and `scan_radius` limitations. Explicitly state that positions in distant bins or unlisted pairs are NOT checked.
   - If `mantle-cli lp lb-positions` returns `total_positions: 0`, do NOT conclude the wallet has no LB exposure — only state that no positions were found within the scan range.
13. Return a formatted report with findings, confidence, and explicit coverage/partial gaps.

## Guardrails

- Use `mantle-cli` read-only commands only for this skill (`mantle-cli account balance`, `mantle-cli account token-balances`, `mantle-cli account allowances`, `mantle-cli aave positions`, `mantle-cli lp positions`, `mantle-cli lp lb-positions`, `mantle-cli token info`, chain/address validation helpers). Do NOT enable or connect to the MCP server.
- Stay read-only; do not construct or send transactions.
- Do not reference direct JSON-RPC calls (`eth_*`) as if they are callable tools in this workflow.
- Do not guess token decimals or symbols if calls fail.
- Validate checksummed addresses for wallet, token, and spender. If an address fails checksum validation or is the zero address (`0x0000...0000`), stop and return an error message explaining the issue -- do not proceed with queries against an invalid address.
- Mark missing token metadata as `unknown` and continue.
- If RPC responses are inconsistent, report partial coverage explicitly.
- Keep both `raw` and `normalized` values in output. Prefer normalized values from tool responses; convert manually only when decimals are explicitly known. If decimals are unavailable, keep raw only and lower confidence.
- Verify response chain/network matches the requested input. Detect and report partial failures via tool-level `partial` flags and per-entry `error` fields.
- If scope is unknown and cannot be discovered, report that coverage is partial instead of inventing token or spender targets.

## Report Format

Always use this exact report structure, even when the user query is scoped to a specific token, spender, or subset. Omit sections only if they are genuinely empty (e.g., no allowances found), but keep all section headers. For scoped queries, populate only the relevant entries within each section and note the applied filter in the summary.

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

Aave V3 Positions
- health_factor:
- health_status: no_debt | safe | moderate | at_risk | liquidatable
- total_collateral_usd:
- total_debt_usd:
- available_borrows_usd:
- positions:
  - symbol:
    supplied:
    borrowed:
    collateral_enabled: true | false | null (null = could not read)
- collateral_warnings:  # flag any position where supplied > 0 but collateral_enabled = false

V3 LP Positions (Agni / Fluxion)
- total_positions:
- positions:
  - provider:
    pool:
    token0/token1:
    liquidity:
    in_range:

Merchant Moe LB Positions
- total_positions:
- positions:
  - pair:
    token_x/token_y:
    bins_with_liquidity:

Allowance Exposure
- token:
  spender:
  allowance_raw:
  allowance_normalized:
  risk_level: low | medium | high | critical
  rationale:

Summary
- tokens_with_balance:
- aave_health_status:
- v3_lp_positions:
- lb_positions:
- allowances_checked:
- unlimited_or_near_unlimited_count:
- key_risks:
- confidence:
```

## References

- `references/rpc-readonly-workflow.md`
- `references/allowance-risk-rules.md`
