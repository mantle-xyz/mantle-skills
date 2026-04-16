# Liquidity Provision Workflow

Load this file when adding/removing liquidity, or when discovering pools / suggesting tick ranges.

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step or jump ahead. Each transaction requires user confirmation (Rule W-2).**

## Pool Discovery & Analysis (run BEFORE adding LP)

```
0. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json
   → Discover the BEST pools across ALL DEXes (no token pair needed)
   → Use when user asks "best LP" or "where to provide liquidity"
   ↓ MUST complete before Step 1

1. mantle-cli lp find-pools --token-a WMNT --token-b USDC --json
   → Discover all available pools for a specific pair across Agni, Fluxion, Merchant Moe
   ↓ MUST complete before Step 2

2. mantle-cli defi analyze-pool --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --investment 1000 --json
   → Get fee APR, multi-range comparison, risk assessment, investment projections
   ↓ MUST complete before Step 3

3. mantle-cli lp suggest-ticks --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --json
   → Get tick range suggestions (wide / moderate / tight strategies)
```

## Add Liquidity — Agni / Fluxion (V3 concentrated)

> **⚠ All discovery steps (0-3) above MUST complete before proceeding to add liquidity.**

```
1. ⚠️ USER CONFIRMATION — present LP Confirmation Summary:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Intent:    <user's original request>
   Operation: Add Liquidity (V3 Concentrated)
   DEX:       <provider>
   Token A:   <amount_a> <tokenA> (≈ $<usd>)
   Token B:   <amount_b> <tokenB> (≈ $<usd>)
   Fee Tier:  <fee_tier>
   Tick Range: <tick_lower> ~ <tick_upper> (<strategy: wide/moderate/tight>)
   Est. APR:  <apr>%
   Warnings:  <IL risk, narrow range warnings, etc.>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   → User must explicitly approve before proceeding to approvals. If "no" → STOP.

   Approve both tokens for the PositionManager:
   mantle-cli approve --token <tokenA> --spender <position_manager> --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success
   mantle-cli approve --token <tokenB> --spender <position_manager> --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success before Step 2

2. mantle-cli lp add \
     --provider agni \
     --token-a WMNT --token-b USDC \
     --amount-a 5 --amount-b 4 \
     --recipient <wallet> \
     --fee-tier 10000 \
     --tick-lower <lower> --tick-upper <upper> \
     --sender <wallet> \
     --json
   ↓ MUST confirm tx success

3. Sign and broadcast → WAIT → Receive NFT position
```

PositionManager addresses for each provider are returned by `mantle-cli lp find-pools --json` and listed in `mantle-cli catalog show lp-add --json`.

## Add Liquidity — Merchant Moe (Liquidity Book)

LB Router V2.2 address: `0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a`

> **⚠ All discovery steps (0-3) MUST complete before proceeding. Steps below are strictly sequential.**

```
1. ⚠️ USER CONFIRMATION — present LP Confirmation Summary:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Intent:       <user's original request>
   Operation:    Add Liquidity (Liquidity Book)
   DEX:          Merchant Moe
   Token A:      <amount_a> <tokenA> (≈ $<usd>)
   Token B:      <amount_b> <tokenB> (≈ $<usd>)
   Bin Step:     <bin_step>
   Active ID:    <active_id>
   Delta IDs:    <delta_ids>
   Distribution: X=<distribution_x>, Y=<distribution_y>
   Warnings:     <IL risk, bin concentration warnings, etc.>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   → User must explicitly approve before proceeding. If "no" → STOP.

   Approve both tokens for the LB Router:
   mantle-cli approve --token <tokenA> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success
   mantle-cli approve --token <tokenB> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success before Step 2

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
   ↓ MUST confirm tx success

3. Sign and broadcast → WAIT → Receive LB tokens
```

## Remove Liquidity / Collect Fees

> **⚠ Each remove/collect operation requires user confirmation (Rule W-2) before execution.**

Use `mantle-cli lp remove` and `mantle-cli lp collect-fees` — see `mantle-cli catalog show <tool-id> --json` for arguments. Present a confirmation summary (position ID, tokens, amounts) to the user before signing.

## Critical rules

- **LP operations are position-manager / router function calls, NOT token transfers.** Sending tokens directly to a PositionManager (Agni / Fluxion) or the LB Router (Merchant Moe) via ERC-20 `transfer()` does NOT create an LP position — the tokens are **permanently locked** in the contract with no recovery path. Always use `mantle-cli lp add` which constructs the correct `mint()` / `increaseLiquidity()` / `addLiquidity()` call. If a user says "send tokens to the position manager" or "deposit into the LP contract", refuse and use `lp add` instead. NEVER construct a transfer to a position manager or router via `utils encode-call` + `build-tx` or any other method.
- **Always pass `--sender <wallet>`** to lp add/remove so the build response carries a scoped `idempotency_key`.
- **NEVER rebuild after timeout** — check the receipt first; rebuilding produces a different nonce that will also execute.
- "sign & WAIT" between every step. Do NOT pre-build multiple LP transactions.
- xStocks LP only works on Fluxion with USDC pairs (fee_tier=3000). Discover specific pools via `mantle-cli lp find-pools --token-a <xstock> --token-b USDC --json`.

## Parameter Reference

### `lp top-pools`

| Param | Required | Description |
|-------|----------|-------------|
| `--sort-by` | Optional | Sort key: `apr`, `tvl`, `volume` (default: `apr`) |
| `--min-tvl` | Optional | Minimum TVL filter in USD (e.g. `10000`) |
| `--json` | ✅ | Machine-parseable output |

### `lp find-pools`

| Param | Required | Description |
|-------|----------|-------------|
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--json` | ✅ | Machine-parseable output |

### `defi analyze-pool`

| Param | Required | Description |
|-------|----------|-------------|
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--fee-tier` | ✅ | Fee tier (e.g. `3000`, `10000`) — for V3 pools |
| `--provider` | ✅ | DEX provider (`agni`, `fluxion`, `merchant_moe`) |
| `--investment` | Optional | Investment amount in USD for projection |
| `--json` | ✅ | Machine-parseable output |

### `lp suggest-ticks`

| Param | Required | Description |
|-------|----------|-------------|
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--fee-tier` | ✅ | Fee tier — for V3 pools |
| `--provider` | ✅ | DEX provider |
| `--json` | ✅ | Machine-parseable output |

### `lp add` (V3 — Agni / Fluxion)

| Param | Required | Description |
|-------|----------|-------------|
| `--provider` | ✅ | `agni` or `fluxion` |
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--amount-a` | ✅ | Amount of token A (human-readable) |
| `--amount-b` | ✅ | Amount of token B (human-readable) |
| `--recipient` | ✅ | Address to receive the NFT position |
| `--fee-tier` | ✅ | Pool fee tier (e.g. `3000`, `10000`) |
| `--tick-lower` | ✅ | Lower tick bound (from `lp suggest-ticks`) |
| `--tick-upper` | ✅ | Upper tick bound (from `lp suggest-ticks`) |
| `--sender` | ✅ | Signing wallet — required for `idempotency_key` |
| `--json` | ✅ | Machine-parseable output |

### `lp add` (LB — Merchant Moe)

| Param | Required | Description |
|-------|----------|-------------|
| `--provider` | ✅ | `merchant_moe` |
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--amount-a` | ✅ | Amount of token A (human-readable) |
| `--amount-b` | ✅ | Amount of token B (human-readable) |
| `--recipient` | ✅ | Address to receive LB tokens |
| `--bin-step` | ✅ | Bin step for the LB pool |
| `--active-id` | ✅ | Active bin ID (from pool state) |
| `--delta-ids` | ✅ | JSON array of bin offsets from active-id |
| `--distribution-x` | ✅ | JSON array of token-X distribution weights |
| `--distribution-y` | ✅ | JSON array of token-Y distribution weights |
| `--sender` | ✅ | Signing wallet |
| `--json` | ✅ | Machine-parseable output |
