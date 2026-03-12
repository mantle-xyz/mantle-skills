# RPC Read-Only Workflow

Use this guide to gather wallet balances and allowances through mantle-mcp v0.2 read-only tools only.

## Required inputs

- Wallet address
- Network (`mainnet` or `sepolia`)
- Token set and spender set (user-provided or discovered)

## Call sequence

1. `mantle_validateAddress` for wallet format checks.
2. `mantle_getChainInfo` (and `mantle_getChainStatus` when available) to confirm network context.
3. `mantle_getBalance({ address: "<wallet>", network: "<network>" })`
4. `mantle_getTokenBalances({ address: "<wallet>", tokens: [...], network: "<network>" })`
5. `mantle_getAllowances({ owner: "<wallet>", pairs: [...], network: "<network>" })`
6. Optional metadata backfill: `mantle_getTokenInfo` for tokens with missing symbol/decimals.

## Token and spender discovery

- Prefer explicit user scope first.
- If token scope is missing, read `mantle://registry/tokens` and select a bounded set for coverage.
- If spender scope is missing, read `mantle://registry/protocols` and extract known routers/pools.
- Use `mantle_resolveToken` for symbols outside the current scoped list before balance/allowance calls.
- If scope is still unknown, report that coverage is partial instead of inventing targets.

## Normalization rules

- Prefer normalized values already returned by mantle-mcp tools.
- Convert raw values manually only when decimals are explicitly known.
- Keep both `raw` and `normalized` values in output.
- If decimals are unavailable, keep raw only and mark confidence lower.

## Reliability checks

- Verify response chain/network matches requested input (`mainnet` or `sepolia`).
- Retry transient read failures with bounded attempts; do not switch to guessed tokens/spenders.
- Detect and report partial failures via tool-level `partial` flags and per-entry `error` fields.
- Include `collected_at_utc` values from tool outputs in the final report.
