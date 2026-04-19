# Liquidity Provision Workflow

Load this file when adding/removing liquidity, or when discovering pools / suggesting tick ranges.

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step or jump ahead. Each transaction requires user confirmation (Rule W-2).**

## ⛔⛔⛔ CALLDATA INTEGRITY — READ BEFORE EVERY `lp add` / `lp remove` / `lp collect-fees` / `approve` SIGN CALL

**See SUPREME RULE in `SKILL.md`.** `lp add` (V3 `mint` / LB `addLiquidity`) is one of the longest calldata paths in the skill — delta_ids arrays, distribution_x/y arrays, tick bounds, and deadline params produce `data` strings that routinely exceed 2000 hex chars. Every single one of those chars MUST reach the Privy signer unchanged.

Before calling the signer on any LP tx, run the 5-question pre-sign verification protocol from `SKILL.md` SUPREME RULE:

1. Raw `mantle-cli` JSON still available? If not, STOP and rebuild.
2. `data` identical to CLI output — same first 16 chars, same last 16 chars, same total length, NO `…` / `...` / `<snip>` / `[truncated]`, NO line wraps, NO inserted whitespace?
3. `to` (PositionManager for V3 / LB Router for Merchant Moe) identical to CLI output? NEVER rewrite this address from memory.
4. `value` (hex wei — usually `0x0` for non-native LP, non-zero for WMNT wraps) identical to CLI output?
5. Array params you passed to the build (`delta_ids`, `distribution_x/y`, tick bounds, `active_id`, `bin_step`) are EXACT values from `lp find-pools` / `lp suggest-ticks` — NOT derived, reformatted, or re-sorted?

If any answer is NO or UNKNOWN, abort. A corrupted LP sign call can mint a position at wildly wrong ticks (100% impermanent loss), send tokens to a wrong router (permanent lock), or cancel the deadline and revert.

**Most common truncation points in LP flows:**
- Long `delta_ids` / `distribution_x/y` JSON arrays serialized with pretty-print or truncated mid-array → wrong position shape.
- Tick bounds (`tickLower`, `tickUpper`) re-encoded from an int to a wider display form → revert.
- PositionManager address rewritten from memory (different per DEX) → tokens sent to wrong contract, locked.

## 🛑 STEP −1 — Always start with `lp find-pools` when ANY asset is specified

If the user expresses an LP intent and names **any** asset — a full pair (A + B) or just a single asset (X) — the FIRST on-chain lookup MUST be `mantle-cli lp find-pools`. Do NOT proceed to `lp analyze`, `suggest-ticks`, `approve`, or `lp add` without the find-pools output in hand. This rule applies every session, every intent, without exception.

- **Learn the subcommand from the CLI**, not from memory. Run `mantle-cli catalog show <find-pools tool-id> --json` (tool-id from `catalog list`) to retrieve the current flag names and see whether single-asset queries are accepted directly or require enumeration.
- **Translate generic asset names first** (§Asset Alias: BTC→FBTC, ETH→mETH/cmETH/WETH, TSLA→wTSLAx, …) before passing to the CLI.
- **Trust the response verbatim** (SUPREME RULE). DEX, fee tier / bin step, PositionManager / Router address, TVL, APR — all come from `find-pools`. Never fabricate them from memory.
- **Empty response → STOP.** Tell the user no whitelisted pool was found — the user asked about a specific asset; either offer the discovered pools or refuse. Never fall back to scanning unrelated pools to "find something to LP".
- Skipping this step is a Hard Constraint #4 violation (fabricated routing) and a Rule W-1 violation (skipping a step).

## 🛑 STEP 0.5 — Pre-Execution Readiness Check (Rule W-9)

**Before ANY write op (add / remove / collect-fees / approve), verify the user's intent is feasible. Two queries, in this order:**

1. **Balance** — `mantle-cli account token-balances <wallet> --json`. Verify `balance(token) ≥ planned input` for EACH token involved (V3 and LB adds take two tokens; removes don't need a balance check). Insufficient → **STOP**, report actual balances, do NOT proceed.
2. **Allowance** — `mantle-cli account allowances <wallet> --pairs <tokenA>:<position_manager>,<tokenB>:<position_manager> --json`. Verify `allowance ≥ planned input` per token. Insufficient → route to the approve flow (Rule W-6). Do NOT silently skip.

Run BOTH checks BEFORE the Transaction Confirmation Summary so it reflects real on-chain state. Skipping either is a hard error.

## Pool Discovery & Analysis (run BEFORE adding LP)

```
1. mantle-cli lp find-pools --token-a WMNT --token-b USDC --json
   → Discover all available pools for a specific pair across Agni, Fluxion, Merchant Moe
   ↓ MUST complete before Step 2

2. mantle-cli lp analyze --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --investment-usd 1000 --json
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
     --sender <wallet> \
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

### `lp find-pools`

| Param | Required | Description |
|-------|----------|-------------|
| `--token-a` | ✅ | First token symbol |
| `--token-b` | ✅ | Second token symbol |
| `--json` | ✅ | Machine-parseable output |

### `lp analyze`

| Param | Required | Description |
|-------|----------|-------------|
| `--token-a` | ✅* | First token symbol (\*or use `--pool`) |
| `--token-b` | ✅* | Second token symbol (\*or use `--pool`) |
| `--fee-tier` | ✅* | V3 fee tier, e.g. `3000`, `10000` (\*or use `--pool`) |
| `--provider` | ✅ | DEX provider (`agni` or `fluxion`) — default `agni` |
| `--pool` | Optional | Pool contract address (alternative to token-a/token-b/fee-tier) |
| `--investment-usd` | Optional | USD amount to project returns for (default: `1000`) |
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
