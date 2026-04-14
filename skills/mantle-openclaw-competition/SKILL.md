---
name: mantle-openclaw-competition
version: 0.1.10
description: "Use when OpenClaw needs to execute DeFi operations for the asset accumulation competition on Mantle. Covers swap, LP, and Aave lending workflows with whitelisted assets and protocols."
---

# OpenClaw Competition — DeFi Operations Guide

## Overview

This skill provides everything OpenClaw needs to execute DeFi operations in the Mantle asset accumulation competition. Each participant starts with 100 MNT in a fresh wallet and competes to grow total portfolio value (USD) through whitelisted protocol interactions.

## Tooling — CLI Only (Mandatory)

**DO NOT enable or connect the `mantle-mcp` MCP server.** All on-chain operations MUST be performed via the `mantle-cli` command-line tool with `--json` output. This eliminates MCP tool-schema overhead and reduces per-session token cost.

### Setup

```bash
# Install mantle-cli (CLI only, no MCP server overhead)
npm install @mantleio/mantle-cli
npx mantle-cli --help   # verify
```

Or, if this skills repo has been cloned with its `package.json`:

```bash
cd <skills-repo-root> && npm install
npx mantle-cli --help   # verify
```

### Key rules

- **Always append `--json`** to every command so the output is machine-parseable JSON.
- **Never start or connect to the MCP server.** Do not configure `mantle-mcp` in any MCP client settings.
- **NEVER fabricate calldata or construct transactions manually** — always use `mantle-cli` build commands. This includes Python `encode_abi`, JS `encodeFunctionData`, manual hex `0xa9059cbb` selectors, or any other method. The CLI handles ALL transfers: `transfer send-native` for MNT, `transfer send-token` for ANY ERC-20.
- **Never add a `from` field** to unsigned transactions — the signer determines `from`.

### Discover available commands

Before using the CLI for the first time, run:

```bash
mantle-cli catalog list --json          # list all 37 capabilities with category, auth, and CLI command template
mantle-cli catalog search "swap" --json # find swap-related capabilities
mantle-cli catalog show <tool-id> --json # full details for a specific capability
```

Each catalog entry includes:
- `category`: `query` (read-only) | `analyze` (computed insights) | `execute` (builds unsigned tx)
- `auth`: `none` | `optional` | `required` (whether a wallet address is needed)
- `cli_command`: the exact CLI command template with placeholders
- `workflow_before`: which tools to call before this one

## When to Use

- User asks to swap tokens on Mantle
- User asks to add/remove liquidity on a DEX
- User asks to supply/borrow on Aave V3
- User asks about available assets or trading pairs
- User asks how to maximize yield or portfolio value

## Whitelisted Assets

Only these assets count toward the competition score:

### Core Tokens

| Symbol | Address | Decimals |
|--------|---------|----------|
| MNT | Native gas token | 18 |
| WMNT | `0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8` | 18 |
| WETH | `0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111` | 18 |
| USDC | `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9` | 6 |
| USDT | `0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE` | 6 |
| USDT0 | `0x779Ded0c9e1022225f8E0630b35a9b54bE713736` | 6 |
| MOE | `0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9` | 18 |

> **USDT vs USDT0:** Both are official USDT on Mantle. Both have DEX liquidity. Only USDT0 is on Aave V3. Swap USDT↔USDT0 on Merchant Moe (bin_step=1).

### xStocks RWA Tokens (Fluxion V3 pools, all paired with USDC, fee_tier 3000)

| Symbol | Address | Pool (USDC pair) |
|--------|---------|-----------------|
| wTSLAx | `0x43680abf18cf54898be84c6ef78237cfbd441883` | `0x5e7935d70b5d14b6cf36fbde59944533fab96b3c` |
| wAAPLx | `0x5aa7649fdbda47de64a07ac81d64b682af9c0724` | `0x2cc6a607f3445d826b9e29f507b3a2e3b9dae106` |
| wCRCLx | `0xa90872aca656ebe47bdebf3b19ec9dd9c5adc7f8` | `0x43cf441f5949d52faa105060239543492193c87e` |
| wSPYx | `0xc88fcd8b874fdb3256e8b55b3decb8c24eab4c02` | `0x373f7a2b95f28f38500eb70652e12038cca3bab8` |
| wHOODx | `0x953707d7a1cb30cc5c636bda8eaebe410341eb14` | `0x4e23bb828e51cbc03c81d76c844228cc75f6a287` |
| wMSTRx | `0x266e5923f6118f8b340ca5a23ae7f71897361476` | `0x0e1f84a9e388071e20df101b36c14c817bf81953` |
| wNVDAx | `0x93e62845c1dd5822ebc807ab71a5fb750decd15a` | `0xa875ac23d106394d1baaae5bc42b951268bc04e2` |
| wGOOGLx | `0x1630f08370917e79df0b7572395a5e907508bbbc` | `0x66960ed892daf022c5f282c5316c38cb6f0c1333` |
| wMETAx | `0x4e41a262caa93c6575d336e0a4eb79f3c67caa06` | `0x782bd3895a6ac561d0df11b02dd6f9e023f3a497` |
| wQQQx | `0xdbd9232fee15351068fe02f0683146e16d9f2cea` | `0x505258001e834251634029742fc73b5cab4fd67d` |

## Whitelisted Protocols & Contracts

### DEX: Merchant Moe (Liquidity Book AMM)

| Contract | Address | Operations |
|----------|---------|-----------|
| MoeRouter | `0xeaEE7EE68874218c3558b40063c42B82D3E7232a` | swap |
| LB Router V2.2 | `0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a` | swap, add/remove LP |

**Key pairs:**
- USDC/USDT0: bin_step=1 (stablecoin)
- USDC/USDT: bin_step=1 (stablecoin)
- USDT/USDT0: bin_step=1 (stablecoin conversion)
- USDe/USDT0: bin_step=1
- USDe/USDT: bin_step=1
- WMNT/USDC: bin_step=20
- WMNT/USDT0: bin_step=20
- WMNT/USDT: bin_step=15
- WMNT/USDe: bin_step=20

### DEX: Agni Finance (Uniswap V3 fork)

| Contract | Address | Operations |
|----------|---------|-----------|
| SwapRouter | `0x319B69888b0d11cEC22caA5034e25FfFBDc88421` | swap |
| PositionManager | `0x218bf598D1453383e2F4AA7b14fFB9BfB102D637` | add/remove LP |

**Key pairs:**
- WETH/WMNT: fee_tier=500 (0.05%)
- USDC/WMNT: fee_tier=10000 (1%)
- USDT0/WMNT: fee_tier=500 (0.05%)
- mETH/WETH: fee_tier=500 (0.05%)

### DEX: Fluxion (Uniswap V3 fork, native to Mantle)

| Contract | Address | Operations |
|----------|---------|-----------|
| SwapRouter | `0x5628a59df0ecac3f3171f877a94beb26ba6dfaa0` | swap |
| PositionManager | `0x2b70c4e7ca8e920435a5db191e066e9e3afd8db3` | add/remove LP |

**All xStocks pools**: USDC paired, fee_tier=3000 (0.3%). See xStocks table above for pool addresses.

### Lending: Aave V3

| Contract | Address | Operations |
|----------|---------|-----------|
| Pool | `0x458F293454fE0d67EC0655f3672301301DD51422` | supply, borrow, repay, withdraw |
| ProtocolDataProvider | `0x487c5c669D9eee6057C44973207101276cf73b68` | read-only queries |

**Supported reserve assets:** WETH, WMNT, USDT0, USDC, USDe, sUSDe, FBTC, syrupUSDT, wrsETH, GHO
> Only USDT0 is supported — NOT USDT. Swap USDT → USDT0 first if needed.

## DeFi Operations — Step-by-Step

### How to Transfer Tokens

**Native MNT transfer:**
```
mantle-cli transfer send-native --to <recipient> --amount <n> --json
→ Sign and broadcast
```

**ERC-20 token transfer (USDC, WMNT, USDT, etc.):**
```
mantle-cli transfer send-token --token <symbol> --to <recipient> --amount <n> --json
→ Sign and broadcast
```

> **IMPORTANT:** NEVER manually compute wei values or hex-encode amounts for transfers. Always use the CLI transfer commands above — they handle decimal conversion deterministically.

### How to Swap Tokens

**Pre-condition:** You have the input token in your wallet.

```
1. mantle-cli swap pairs --json
   → Find the pair and its params (bin_step or fee_tier)

2. mantle-cli defi swap-quote --in X --out Y --amount 10 --provider best --json
   → Get the expected output and minimum_out

3. mantle-cli account allowances <wallet> --pairs X:<router> --json
   → Check if already approved

4. IF allowance < amount:
   mantle-cli swap approve --token X --spender <router> --amount <amount> --json
   → Sign and broadcast

5. mantle-cli swap build-swap --provider <dex> --in X --out Y --amount 10 --recipient <wallet> --amount-out-min <from_quote> --json
   → Sign and broadcast
```

**For MNT → Token swaps:** Wrap MNT first with `mantle-cli swap wrap-mnt --amount <n> --json`, then swap WMNT.

### How to Add Liquidity

**Agni / Fluxion (V3 concentrated liquidity):**
```
1. Approve both tokens for the PositionManager
   mantle-cli swap approve --token <tokenA> --spender <position_manager> --amount <n> --json
   mantle-cli swap approve --token <tokenB> --spender <position_manager> --amount <n> --json

2. mantle-cli lp add \
     --provider agni \
     --token-a WMNT --token-b USDC \
     --amount-a 5 --amount-b 4 \
     --recipient <wallet> \
     --fee-tier 10000 \
     --tick-lower <lower> --tick-upper <upper> \
     --json

3. Sign and broadcast → Receive NFT position
```

**Merchant Moe (Liquidity Book):**
```
1. Approve both tokens for LB Router (0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a)
   mantle-cli swap approve --token <tokenA> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json
   mantle-cli swap approve --token <tokenB> --spender 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a --amount <n> --json

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

3. Sign and broadcast → Receive LB tokens
```

### How to Use Aave V3

**Supply (earn interest):**
```
1. mantle-cli swap approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 100 --json
   → Sign and broadcast

2. mantle-cli aave supply --asset USDC --amount 100 --on-behalf-of <wallet> --json
   → Sign and broadcast → Receive aUSDC (grows with interest)
```

**Borrow (leverage):**
```
1. Supply collateral first (see above)

2. mantle-cli aave positions --user <wallet> --json
   → Verify collateral_enabled=YES for the supplied asset
   → If collateral_enabled=NO or total_collateral_usd=0:

3. mantle-cli aave set-collateral --asset <supplied_asset> --user <wallet> --json
   → Use the ACTUAL asset you supplied (e.g. WMNT, WETH, USDC) — not always WMNT
   → Runs preflight diagnostics (checks aToken balance, LTV, reserve status)
   → If LTV_IS_ZERO: this asset CANNOT be collateral by design — do NOT proceed
   → Sign and broadcast → Enables the supplied asset as collateral
   → IMPORTANT: the signing wallet MUST be <wallet> itself (set-collateral operates on msg.sender)

4. mantle-cli aave borrow --asset USDC --amount 50 --on-behalf-of <wallet> --json
   → Sign and broadcast → Receive USDC, incur variableDebtUSDC
```

NOTE: Step 3 is only needed if collateral was NOT auto-enabled after supply. This is
especially common with Isolation Mode assets (WMNT, WETH). Always verify with positions first.

**Repay:**
```
1. mantle-cli swap approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 50 --json
2. mantle-cli aave repay --asset USDC --amount 50 --on-behalf-of <wallet> --json
   OR --amount max to repay full debt
```

**Withdraw:**
```
1. mantle-cli aave withdraw --asset USDC --amount 50 --to <wallet> --json
   OR --amount max for full balance
```

### How to Analyze Pools Before LP

Before adding liquidity, analyze the pool to choose the best range and estimate returns:

```
0. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json
   → Discover the BEST pools across ALL DEXes (no token pair needed) — use when user asks "best LP" or "where to provide liquidity"

1. mantle-cli lp find-pools --token-a WMNT --token-b USDC --json
   → Discover all available pools for a specific pair across Agni, Fluxion, Merchant Moe

2. mantle-cli defi analyze-pool --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --investment 1000 --json
   → Get fee APR, multi-range comparison, risk assessment, investment projections

3. mantle-cli lp suggest-ticks --token-a WMNT --token-b USDC --fee-tier 3000 --provider agni --json
   → Get tick range suggestions (wide/moderate/tight strategies)
```

## Safety Rules

**⛔ ABSOLUTE PROHIBITION — MANUAL TRANSACTION CONSTRUCTION ⛔**

You MUST NEVER, under ANY circumstances, do ANY of the following:
- Compute calldata, function selectors, or ABI-encoded parameters yourself (via Python, JS, manual hex, or any other method)
- Manually hex-encode token amounts, wei values, or transfer data
- Construct `unsigned_tx` objects by hand instead of using `mantle-cli`
- Use Python/JS scripts to build or encode transaction data
- Call `sign evm-transaction`, `eth_sendRawTransaction`, or any direct broadcast tool with manually constructed data
- Claim "the CLI doesn't support this operation" as justification for manual construction

**This prohibition has NO exceptions.** If you believe the CLI doesn't support an operation, you are WRONG — check the catalog first. If it truly doesn't exist, use the safe encoding utilities below. Do NOT use Python/JS.

**EVERY on-chain operation the CLI supports:**
```
mantle-cli transfer send-native --to <addr> --amount <n> --json        # Native MNT transfer
mantle-cli transfer send-token --token <sym> --to <addr> --amount <n> --json  # ANY ERC-20 transfer (USDC, USDT, WMNT, etc.)
mantle-cli swap wrap-mnt --amount <n> --json                           # Wrap MNT → WMNT
mantle-cli swap unwrap-mnt --amount <n> --json                         # Unwrap WMNT → MNT
mantle-cli swap approve --token <t> --spender <addr> --amount <n> --json  # ERC-20 approve
mantle-cli swap build-swap --provider <dex> --in <t> --out <t> --amount <n> --recipient <addr> --json  # DEX swap
mantle-cli lp add / remove / collect-fees ...                          # LP operations
mantle-cli aave supply / borrow / repay / withdraw / set-collateral ...  # Aave operations
```

**Safe encoding utilities (ESCAPE HATCH for unsupported operations):**
If the operation truly has no dedicated CLI command, use these utils instead of Python/JS:
```
mantle-cli utils parse-units --amount <decimal> --decimals <n> --json   # Step 1: Decimal → raw/wei (NEVER compute manually!)
mantle-cli utils format-units --amount-raw <raw> --decimals <n> --json  # Reverse: Raw/wei → decimal
mantle-cli utils encode-call --abi '<abi>' --function <name> --args '<json>' --json  # Step 2: ABI-encode function call → hex calldata
mantle-cli utils build-tx --to <addr> --data <hex> [--value <mnt>] --json  # Step 3: Wrap calldata into unsigned_tx (validates address + hex)
```
**Full workflow for unsupported operations:**
1. `parse-units` — convert any decimal amounts to raw integers
2. `encode-call` — ABI-encode the function call with the raw integer args
3. `build-tx` — wrap the calldata + target address into a validated unsigned_tx
This replaces ALL manual Python/JS computation. The output is an `unsigned_tx` with `⚠ UNVERIFIED` warning.

**Real incident**: Agent bypassed `mantle-cli transfer send-token` for a USDC transfer, manually computed calldata with Python, and produced incorrect encoding — causing fund loss. The CLI command `mantle-cli transfer send-token --token USDC --to <addr> --amount <n>` would have handled this correctly and safely.

---

0. **NEVER BUILD THE SAME TRANSACTION TWICE (CRITICAL — FUND SAFETY)**:
   - Call each build command EXACTLY ONCE per user-requested action. NEVER call the same build command a second time with identical parameters to "verify" or "retry" — each built transaction may be signed and broadcast, causing **duplicate transfers and irreversible fund loss**.
   - Every build response includes an `idempotency_key` scoped to the signing wallet. ALWAYS pass `sender=<signing_wallet>` when calling build tools. If you accidentally call a builder twice and get the same key, the signer must execute only ONE.
   - If a transaction times out or you lose track of it, do NOT rebuild. Check the receipt first: `mantle-cli chain tx --hash <hash>`. The original may have already been mined. Rebuilding creates a new transaction with a different nonce that will ALSO execute.
   - **Real incident**: duplicate build calls caused 2× transfers to the same recipients — 0.2 MNT sent twice and 0.608 MNT sent twice.
1. **CLI only — never use MCP** — All operations via `mantle-cli ... --json`. Do not enable or connect to the MCP server.
2. **Never fabricate calldata outside the CLI** — Always use `mantle-cli` build commands or `mantle-cli utils encode-call` + `mantle-cli utils build-tx`. NEVER use Python `encode_abi`, JS `encodeFunctionData`, manual `0xa9059cbb` selectors, or any non-CLI method to produce calldata.
3. **Never manually compute hex/wei values** — NEVER use Python, JS, or mental arithmetic to calculate `amount * 10**decimals` or hex-encode transfer amounts. Use `mantle-cli utils parse-units` for decimal→raw conversion. Use `mantle-cli transfer send-native` for MNT transfers and `mantle-cli transfer send-token` for ANY ERC-20 transfers. Real incident: manual hex computation produced wrong amounts (15 MNT intended → 56.28 MNT sent).
4. **Always check allowance before approve** — Don't approve if already sufficient.
5. **Always get a quote before swap** — Use `mantle-cli defi swap-quote` to know expected output and get `minimum_out_raw` for slippage protection.
6. **Never set allow_zero_min in production** — Always pass `amount_out_min` from the swap quote. Swaps without slippage protection are vulnerable to sandwich attacks and MEV extraction.
7. **Wait for tx confirmation** — Do not build the next tx until the previous one is confirmed on-chain.
8. **Show `human_summary`** — Present every build command's summary to the user before signing.
9. **Value field is hex** — The `unsigned_tx.value` is hex-encoded (e.g., "0x0"). Pass it directly to the signer.
10. **MNT is gas, not ERC-20** — MNT is the native gas token. To swap MNT, wrap it to WMNT first (`mantle-cli swap wrap-mnt`). To transfer MNT, use `mantle-cli transfer send-native`. Do NOT pass "MNT" to swap/approve/LP commands — those require WMNT.
11. **Unsupported operations — USE UTILS, NOT PYTHON** — If a user requests an operation that has no corresponding dedicated `mantle-cli` command:
    - **Warn the user** that this operation is not covered by standard CLI tooling and carries higher risk
    - **Use the CLI utils pipeline** (NEVER Python/JS): `utils parse-units` → `utils encode-call` → `utils build-tx`
    - **Require explicit user confirmation** before signing the `⚠ UNVERIFIED` unsigned_tx
    - If the user confirms, present the unsigned_tx with the **"⚠ UNVERIFIED MANUAL CONSTRUCTION"** warning visible
12. **xStocks tokens are Fluxion-only** — All xStocks RWA tokens (wTSLAx, wAAPLx, wCRCLx, wSPYx, wHOODx, wMSTRx, wNVDAx, wGOOGLx, wMETAx, wQQQx) only have liquidity on Fluxion with USDC pairs (fee_tier=3000). Do NOT attempt to swap xStocks on Agni or Merchant Moe — no pool exists and the transaction will fail.
13. **Verify transactions after broadcast** — After the user signs and broadcasts a transaction, always verify the result using `mantle-cli chain tx --hash <tx_hash> --json`. Check `status` is `"success"`. NEVER manually call `eth_getTransactionReceipt` or parse raw RPC JSON — use the CLI which handles value decoding correctly.
14. **Estimate gas before signing** — For large or complex operations, use `mantle-cli chain estimate-gas --to <addr> --data <hex> --value <hex> --json` to show the user the expected fee in MNT before signing.
15. **Transaction history** — The CLI cannot query full transaction history. If a user asks about past transactions, direct them to the Mantle Explorer: `https://mantlescan.xyz/address/<wallet_address>`. For verifying a single known transaction, use `mantle-cli chain tx --hash <hash>`.

## Multi-Step Operation Ordering

Many DeFi operations require multiple transactions in strict order. **NEVER skip steps or execute out of order** — this causes on-chain reverts and wastes gas.

### Swap (MNT → Token)
```
1. mantle-cli swap wrap-mnt --amount <n>           → sign & WAIT for confirmation
2. mantle-cli defi swap-quote --in WMNT --out X    → get minimum_out_raw
3. mantle-cli account allowances <wallet> --pairs WMNT:<router>  → check allowance
4. IF insufficient: mantle-cli swap approve ...    → sign & WAIT for confirmation
5. mantle-cli swap build-swap ...                  → sign & WAIT for confirmation
```

### Swap (Token → Token)
```
1. mantle-cli defi swap-quote --in X --out Y       → get minimum_out_raw
2. mantle-cli account allowances <wallet> --pairs X:<router>
3. IF insufficient: mantle-cli swap approve ...    → sign & WAIT for confirmation
4. mantle-cli swap build-swap ...                  → sign & WAIT for confirmation
```

### Aave Supply → Borrow
```
1. mantle-cli swap approve --token X --spender 0x458F... --amount <n>  → sign & WAIT
2. mantle-cli aave supply --asset X --amount <n> --on-behalf-of <wallet>  → sign & WAIT
3. mantle-cli aave positions --user <wallet>       → verify collateral_enabled
4. IF collateral_enabled=NO: mantle-cli aave set-collateral --asset X --user <wallet>  → sign & WAIT
5. mantle-cli aave borrow --asset Y --amount <n> --on-behalf-of <wallet>  → sign & WAIT
```

### Add Liquidity (V3)
```
1. mantle-cli lp find-pools --token-a A --token-b B   → discover pools
2. mantle-cli defi analyze-pool ...                    → check APR, risk
3. mantle-cli lp suggest-ticks ...                     → get tick range recommendations
4. mantle-cli swap approve --token A --spender <pm>    → sign & WAIT
5. mantle-cli swap approve --token B --spender <pm>    → sign & WAIT
6. mantle-cli lp add ...                               → sign & WAIT
```

> **CRITICAL**: "sign & WAIT" means you must wait for on-chain confirmation (use `mantle-cli chain tx --hash <hash>` to verify `status: success`) before proceeding to the next step. Do NOT pipeline multiple unsigned transactions. Do NOT rebuild a transaction if the previous attempt timed out — check the receipt first.

## Competition Scoring

```
Net Value (USD) = Sum(token holdings * price) + Sum(aToken balances * price) - Sum(debtToken balances * price)
```

- aToken balances grow over time (interest earned)
- debtToken balances grow over time (interest owed)
- LP positions valued by underlying token amounts
- Only interactions with whitelisted contracts count

## ⚠️ CLI Coverage Boundary — MUST READ

The `mantle-cli` covers the following **verified-safe** operations:

| Category | Supported Operations |
|----------|---------------------|
| **Transfers** | Native MNT transfer, ERC-20 token transfer |
| **Swaps** | Agni, Fluxion, Merchant Moe (direct + multi-hop) |
| **LP** | V3 add/remove/collect-fees (Agni, Fluxion), LB add/remove (Merchant Moe) |
| **Lending** | Aave V3 supply, borrow, repay, withdraw, set-collateral |
| **Utility** | Wrap/unwrap MNT, ERC-20 approve, tx receipt, gas estimation |
| **Read-only** | Balances, quotes, pool state, positions, prices, chain status |

**Any operation NOT listed above has NO CLI support.** This includes but is not limited to:
- Interacting with non-whitelisted protocols or contracts
- Calling arbitrary smart contract functions
- Token approvals to non-whitelisted spenders
- Bridge operations
- NFT operations
- Governance/voting operations

### When a User Requests an Unsupported Operation

You MUST follow this exact protocol:

1. **Immediately inform the user**: "⚠️ This operation is not covered by the verified CLI tooling."
2. **Explain the risk clearly**: "All subsequent operations for this request will be constructed manually. Manual transaction construction bypasses the CLI's safety guarantees — including decimal/hex conversion verification, address whitelist checks, and parameter validation. **Incorrect construction can result in irreversible loss of funds.**"
3. **Suggest alternatives**: If a supported operation can achieve the same goal, recommend it.
4. **Require explicit confirmation**: Do NOT proceed unless the user explicitly says they understand the risk and want to continue.
5. **If the user confirms**: Prefix every manually constructed transaction with `⚠️ UNVERIFIED MANUAL CONSTRUCTION` and remind the user to **double-check all values** (especially amounts and addresses) before signing.
6. **If in doubt, refuse**: It is always safer to decline an unsupported operation than to risk user funds.
