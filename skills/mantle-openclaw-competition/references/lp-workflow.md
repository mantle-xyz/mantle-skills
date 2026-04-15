# Liquidity Provision Workflow

Load this file when adding/removing liquidity, or when discovering pools / suggesting tick ranges.

## Pool Discovery & Analysis (run BEFORE adding LP)

```
0. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json
   → Discover the BEST pools across ALL DEXes (no token pair needed)
   → Use when user asks "best LP" or "where to provide liquidity"

1. mantle-cli lp find-pools --token-a WMNT --token-b USDC --json
   → Discover all available pools for a specific pair across Agni, Fluxion, Merchant Moe

2. mantle-cli defi analyze-pool --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --investment 1000 --json
   → Get fee APR, multi-range comparison, risk assessment, investment projections

3. mantle-cli lp suggest-ticks --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --json
   → Get tick range suggestions (wide / moderate / tight strategies)
```

## Add Liquidity — Agni / Fluxion (V3 concentrated)

```
1. Approve both tokens for the PositionManager
   mantle-cli approve --token <tokenA> --spender <position_manager> --amount <n> --json   → sign & WAIT
   mantle-cli approve --token <tokenB> --spender <position_manager> --amount <n> --json   → sign & WAIT

2. mantle-cli lp add \
     --provider agni \
     --token-a WMNT --token-b USDC \
     --amount-a 5 --amount-b 4 \
     --recipient <wallet> \
     --fee-tier 10000 \
     --tick-lower <lower> --tick-upper <upper> \
     --sender <wallet> \
     --json

3. Sign and broadcast → WAIT → Receive NFT position
```

PositionManager addresses for each provider are returned by `mantle-cli lp find-pools --json` and listed in `mantle-cli catalog show lp-add --json`.

## Add Liquidity — Merchant Moe (Liquidity Book)

LB Router V2.2 address: `0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a`

```
1. Approve both tokens for the LB Router
   mantle-cli approve --token <tokenA> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json   → sign & WAIT
   mantle-cli approve --token <tokenB> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json   → sign & WAIT

2. mantle-cli lp add \
     --provider merchant_moe \
     --token-a WMNT --token-b USDe \
     --amount-a 5 --amount-b 4 \
     --recipient <wallet> \
     --bin-step 20 \
     --active-id <from_pool> \
     --delta-ids '[-5,-4,-3,-2,-1,0,1,2,3,4,5]' \
     --distribution-x '[0,0,0,0,0,0,1e17,1e17,2e17,2e17,3e17]' \
     --distribution-y '[3e17,2e17,2e17,1e17,1e17,0,0,0,0,0,0]' \
     --json

3. Sign and broadcast → WAIT → Receive LB tokens
```

## Remove Liquidity / Collect Fees

Use `mantle-cli lp remove` and `mantle-cli lp collect-fees` — see `mantle-cli catalog show <tool-id> --json` for arguments.

## Critical rules

- **LP operations are position-manager / router function calls, NOT token transfers.** Sending tokens directly to a PositionManager (Agni / Fluxion) or the LB Router (Merchant Moe) via ERC-20 `transfer()` does NOT create an LP position — the tokens are **permanently locked** in the contract with no recovery path. Always use `mantle-cli lp add` which constructs the correct `mint()` / `increaseLiquidity()` / `addLiquidity()` call. If a user says "send tokens to the position manager" or "deposit into the LP contract", refuse and use `lp add` instead. NEVER construct a transfer to a position manager or router via `utils encode-call` + `build-tx` or any other method.
- **Always pass `--sender <wallet>`** to lp add/remove so the build response carries a scoped `idempotency_key`.
- **NEVER rebuild after timeout** — check the receipt first; rebuilding produces a different nonce that will also execute.
- "sign & WAIT" between every step. Do NOT pre-build multiple LP transactions.
- xStocks LP only works on Fluxion with USDC pairs (fee_tier=3000). Discover specific pools via `mantle-cli lp find-pools --token-a <xstock> --token-b USDC --json`.
