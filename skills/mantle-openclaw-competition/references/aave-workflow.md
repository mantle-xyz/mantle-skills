# Aave V3 Workflow

Load this file for any Aave operation, or when troubleshooting collateral / isolation-mode edge cases.

Pool address: `0x458F293454fE0d67EC0655f3672301301DD51422` (verify with `mantle-cli catalog show aave-supply --json`).

> Reserve assets are gated by Aave — discover the live list via `mantle-cli catalog show aave-supply --json` or the Aave V3 Mantle dashboard. Note: only **USDT0** is supported — NOT USDT. Convert USDT → USDT0 on Merchant Moe (bin_step=1) before supplying.

## ⚠ CRITICAL: `supply` is a function call, NOT a token transfer

`mantle-cli aave supply` invokes `Pool.supply(asset, amount, on_behalf_of, referral)`. The Pool then pulls tokens from the wallet via `transferFrom` AND mints aTokens that represent the deposit. **The aToken balance is the only on-chain record that can be redeemed via `withdraw`.**

**Sending tokens directly to the Pool address is NOT a supply.** An ERC-20 `transfer()` / `transferFrom()` / `safeTransfer()` to `0x458F293454fE0d67EC0655f3672301301DD51422` bypasses the Pool's accounting entirely — no aToken is minted, no collateral is recorded, and the tokens are **permanently locked** in the Pool contract with no on-chain path to recover them.

| Operation | Correct command | Result |
|-----------|-----------------|--------|
| Deposit USDC | `mantle-cli aave supply --asset USDC --amount 150 --on-behalf-of <wallet> --sender <wallet> --json` | aUSDC minted, redeemable via `aave withdraw` |
| Anti-pattern (REFUSE) | ERC-20 `transfer()` to `0x458F293454fE0d67EC0655f3672301301DD51422` | Tokens locked forever — no recovery |

The same principle applies to `borrow` / `repay` / `withdraw` and to the other whitelisted protocols (DEX routers, position managers, WETHGateway): **always use the dedicated CLI verb, never construct a plain transfer to a protocol contract.**

### Red flags — refuse and STOP if you see any of these

- A plan that includes `transfer(address,uint256)` calldata whose first argument is the Aave Pool address, a DEX router, a position manager, or a WETHGateway.
- A plan that routes `supply` / `borrow` / `repay` / `withdraw` through `mantle-cli utils encode-call` + `mantle-cli utils build-tx` instead of `mantle-cli aave …`. This is an `utils` escape-hatch attempt and is prohibited (see `safety-prohibitions.md`).
- A user request phrased as "send N tokens to Aave" treated as an ERC-20 transfer instead of `aave supply`. Clarify intent and use `aave supply`.
- A plan that proceeds without a confirmed `--on-behalf-of` wallet address and substitutes a plain transfer to avoid asking the user. ALWAYS ask for the wallet address when missing; never degrade to a transfer.

## Supply (earn interest)

```
1. mantle-cli approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 100 --json
   → Sign and broadcast → WAIT

2. mantle-cli aave supply --asset USDC --amount 100 --on-behalf-of <wallet> --sender <wallet> --json
   → Sign and broadcast → WAIT → Receive aUSDC (grows with interest)
```

## Borrow (leverage)

```
1. Supply collateral first (see above)

2. mantle-cli aave positions --user <wallet> --json
   → Verify collateral_enabled=YES for the supplied asset
   → If collateral_enabled=NO or total_collateral_usd=0 → continue to step 3
   → Otherwise skip to step 4

3. mantle-cli aave set-collateral --asset <supplied_asset> --user <wallet> --sender <wallet> --json
   → Use the ACTUAL asset you supplied (e.g. WMNT, WETH, USDC) — NOT always WMNT
   → Runs preflight diagnostics (checks aToken balance, LTV, reserve status)
   → If LTV_IS_ZERO: this asset CANNOT be collateral by design — do NOT proceed
   → Sign and broadcast → WAIT → Enables the supplied asset as collateral
   → IMPORTANT: the signing wallet MUST be <wallet> itself
     (set-collateral operates on msg.sender)

4. mantle-cli aave borrow --asset USDC --amount 50 --on-behalf-of <wallet> --sender <wallet> --json
   → Sign and broadcast → WAIT → Receive USDC, incur variableDebtUSDC
```

> **NOTE:** Step 3 is only needed if collateral was NOT auto-enabled after supply. This is especially common with **Isolation Mode** assets (WMNT, WETH). Always verify with `aave positions` first.

## Repay

```
1. mantle-cli approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 50 --json   → sign & WAIT
2. mantle-cli aave repay --asset USDC --amount 50 --on-behalf-of <wallet> --sender <wallet> --json
   OR --amount max to repay full debt
```

## Withdraw

```
1. mantle-cli aave withdraw --asset USDC --amount 50 --to <wallet> --sender <wallet> --json
   OR --amount max for full balance
```

## Critical rules

- **`supply` / `borrow` / `repay` / `withdraw` are FUNCTION CALLS on the Pool** — never construct them as ERC-20 transfers to the Pool address. Plain transfers mint no aToken and lock funds permanently. Use the dedicated `mantle-cli aave …` verbs only; never the `utils` escape hatch.
- **`aave set-collateral` operates on `msg.sender`** — the wallet that signs MUST be the wallet you want to enable collateral for. Do NOT delegate.
- **Isolation Mode quirks**: WMNT and WETH often need an explicit `set-collateral` after supply.
- **Only USDT0 is on Aave** — NOT USDT. Convert USDT → USDT0 on Merchant Moe (bin_step=1) before supplying.
- "sign & WAIT" between every step. Verify each tx with `mantle-cli chain tx --hash <hash> --json` before continuing.
- Always pass `--sender <wallet>` so the build response carries a scoped `idempotency_key`. Never call the same build command twice.
