# Aave V3 Workflow

Load this file for any Aave operation, or when troubleshooting collateral / isolation-mode edge cases.

Pool address: `0x458F293454fE0d67EC0655f3672301301DD51422` (verify with `mantle-cli catalog show aave-supply --json`).

> Reserve assets are gated by Aave — discover the live list via `mantle-cli catalog show aave-supply --json` or the Aave V3 Mantle dashboard. Note: only **USDT0** is supported — NOT USDT. Convert USDT → USDT0 on Merchant Moe (bin_step=1) before supplying.

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step or jump ahead. Each transaction requires user confirmation (Rule W-2).**

## ⛔⛔⛔ CALLDATA INTEGRITY — READ BEFORE EVERY `aave supply` / `borrow` / `repay` / `withdraw` / `set-collateral` / `approve` SIGN CALL

**See SUPREME RULE in `SKILL.md`.** Aave V3 Pool function calls are function-selector + packed struct arguments — typically shorter than swap/LP calldata, but STILL must pass byte-for-byte. A single dropped byte changes the function selector, the asset address, the amount, or `referralCode` — any of which can route the call to a different function (`supply` → `borrow`, or worse, a proxy-admin call).

Before calling the signer on any Aave tx, run the 5-question pre-sign verification protocol from `SKILL.md` SUPREME RULE:

1. Raw `mantle-cli` JSON still available? If not, STOP and rebuild.
2. `data` identical to CLI output — same first 16 chars (function selector + start of first arg), same last 16 chars, same total length, NO `…` / `...` / `<snip>` / `[truncated]`?
3. `to` (Aave V3 Pool `0x458F293454fE0d67EC0655f3672301301DD51422` or WETHGateway per CLI response) identical to CLI output? NEVER rewrite the Pool address from memory — type it from the CLI JSON.
4. `value` (hex wei) identical to CLI output?
5. `--on-behalf-of` argument you passed is the EXACT wallet address from the user — no checksum re-casing, no truncation?

If any answer is NO or UNKNOWN, abort. A corrupted Aave sign call can supply to the wrong asset reserve (tokens locked), borrow the wrong asset, or — in the classic incident — end up as a bare `transfer()` to the Pool address that mints NO aToken and locks the funds permanently.

**Most common truncation points in Aave flows:**
- Pool address re-typed from memory with a checksum typo → tx routes to no contract / to a different address.
- `amount` argument reformatted from raw integer → silent wrong supply amount.
- `interestRateMode` / `referralCode` trailing bytes dropped → selector decodes to a different function.

## 🛑 STEP 0.5 — Pre-Execution Readiness Check (Rule W-9)

**Before ANY write op (supply / borrow / repay / withdraw / set-collateral / approve), verify the user's intent is feasible against actual on-chain state. Two queries, in this order:**

1. **Balance** — `mantle-cli account token-balances <wallet> --json`.
   - `supply` / `repay`: verify `balance(asset) ≥ amount`.
   - `withdraw`: verify `aToken balance ≥ amount` (withdrawing the underlying burns aTokens).
   - `borrow` / `set-collateral`: no balance check needed.
   - Insufficient → **STOP**, report the actual balance, do NOT proceed.
2. **Allowance** — `mantle-cli account allowances <wallet> --pairs <asset>:0x458F293454fE0d67EC0655f3672301301DD51422 --json` (Pool is the spender).
   - Required for `supply` and `repay`.
   - Not applicable for `withdraw` / `borrow` / `set-collateral`.
   - Insufficient → route to the approve flow (Rule W-6). Do NOT silently skip.

Run BOTH checks (where applicable) BEFORE the Transaction Confirmation Summary so it reflects real on-chain state. Skipping either is a hard error.

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

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step. Each transaction requires user confirmation (Rule W-2).**

```
1. ⚠️ USER CONFIRMATION — present Supply Confirmation Summary:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Intent:    <user's original request>
   Operation: Aave Supply
   Asset:     <amount> <token> (≈ $<usd>)
   Receives:  a<token> (interest-bearing receipt)
   On behalf: <wallet>
   Spender:   0x458F293454fE0d67EC0655f3672301301DD51422
   Warnings:  <Isolation Mode caveats, if applicable>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   → User must explicitly approve before proceeding. If "no" → STOP.

   mantle-cli approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 100 --json
   → Sign and broadcast → WAIT
   ↓ MUST confirm tx success before Step 2

2. mantle-cli aave supply --asset USDC --amount 100 --on-behalf-of <wallet> --sender <wallet> --json
   → ⚠️ USER CONFIRMATION (if not already covered in Step 1's summary) → Sign and broadcast → WAIT → Receive aUSDC (grows with interest)
```

## Borrow (leverage)

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step. Each transaction requires user confirmation (Rule W-2).**

```
1. Supply collateral first (see above — all supply steps must complete)
   ↓ MUST confirm supply tx success before Step 2

2. mantle-cli aave positions --user <wallet> --json
   → Verify collateral_enabled=YES for the supplied asset
   → If collateral_enabled=NO or total_collateral_usd=0 → continue to step 3
   → Otherwise skip to step 4
   ↓ MUST complete before Step 3

3. ⚠️ USER CONFIRMATION — present set-collateral details (asset, wallet)
   mantle-cli aave set-collateral --asset <supplied_asset> --user <wallet> --sender <wallet> --json
   → Use the ACTUAL asset you supplied (e.g. WMNT, WETH, USDC) — NOT always WMNT
   → Runs preflight diagnostics (checks aToken balance, LTV, reserve status)
   → If LTV_IS_ZERO: this asset CANNOT be collateral by design — do NOT proceed
   → Sign and broadcast → WAIT → Enables the supplied asset as collateral
   → IMPORTANT: the signing wallet MUST be <wallet> itself
     (set-collateral operates on msg.sender)
   ↓ MUST confirm tx success before Step 4

4. ⚠️ USER CONFIRMATION — present Borrow Confirmation Summary:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Intent:         <user's original request>
   Operation:      Aave Borrow
   Borrow asset:   <amount> <token> (≈ $<usd>)
   Health factor:  <current_health_factor>
   Projected HF:   <after_borrow_health_factor>
   Liquidation:    <warning if HF < 1.5>
   On behalf:      <wallet>
   Warnings:       <Isolation Mode, high utilization, etc.>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   → User must explicitly approve before proceeding. If "no" → STOP.

   mantle-cli aave borrow --asset USDC --amount 50 --on-behalf-of <wallet> --sender <wallet> --json
   → Sign and broadcast → WAIT → Receive USDC, incur variableDebtUSDC
```

> **NOTE:** Step 3 is only needed if collateral was NOT auto-enabled after supply. This is especially common with **Isolation Mode** assets (WMNT, WETH). Always verify with `aave positions` first.

## Repay

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

```
1. ⚠️ USER CONFIRMATION — present Repay Confirmation Summary:
   - Intent, repay asset, amount (or "max"), current debt balance, wallet address
   → User must explicitly approve before proceeding. If "no" → STOP.

   mantle-cli approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount 50 --json   → sign & WAIT
   ↓ MUST confirm tx success before Step 2

2. mantle-cli aave repay --asset USDC --amount 50 --on-behalf-of <wallet> --sender <wallet> --json
   OR --amount max to repay full debt
   → sign & WAIT
```

## Withdraw

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

```
1. ⚠️ USER CONFIRMATION — present Withdraw Confirmation Summary:
   - Intent, withdraw asset, amount (or "max"), current aToken balance, impact on health factor (if borrowing), wallet address
   → User must explicitly approve before proceeding. If "no" → STOP.

   mantle-cli aave withdraw --asset USDC --amount 50 --to <wallet> --sender <wallet> --json
   OR --amount max for full balance
   → sign & WAIT
```

## Critical rules

- **`supply` / `borrow` / `repay` / `withdraw` are FUNCTION CALLS on the Pool** — never construct them as ERC-20 transfers to the Pool address. Plain transfers mint no aToken and lock funds permanently. Use the dedicated `mantle-cli aave …` verbs only; never the `utils` escape hatch.
- **`aave set-collateral` operates on `msg.sender`** — the wallet that signs MUST be the wallet you want to enable collateral for. Do NOT delegate.
- **Isolation Mode quirks**: WMNT and WETH often need an explicit `set-collateral` after supply.
- **Only USDT0 is on Aave** — NOT USDT. Convert USDT → USDT0 on Merchant Moe (bin_step=1) before supplying.
- "sign & WAIT" between every step. Verify each tx with `mantle-cli chain tx --hash <hash> --json` before continuing.
- Always pass `--sender <wallet>` so the build response carries a scoped `idempotency_key`. Never call the same build command twice.

## Parameter Reference

### `aave supply`

| Param | Required | Description |
|-------|----------|-------------|
| `--asset` | ✅ | Token symbol to supply (e.g. `USDC`, `USDT0`, `WMNT`) — NOT `USDT` |
| `--amount` | ✅ | Amount to supply (human-readable) |
| `--on-behalf-of` | ✅ | Wallet address that receives aTokens — NEVER omit |
| `--sender` | ✅ | Signing wallet — required for `idempotency_key` |
| `--json` | ✅ | Machine-parseable output |

### `aave borrow`

| Param | Required | Description |
|-------|----------|-------------|
| `--asset` | ✅ | Token symbol to borrow |
| `--amount` | ✅ | Amount to borrow (human-readable) |
| `--on-behalf-of` | ✅ | Wallet address that incurs the debt |
| `--sender` | ✅ | Signing wallet |
| `--json` | ✅ | Machine-parseable output |

### `aave repay`

| Param | Required | Description |
|-------|----------|-------------|
| `--asset` | ✅ | Token symbol to repay |
| `--amount` | ✅ | Amount to repay, or `max` for full debt |
| `--on-behalf-of` | ✅ | Wallet address whose debt to repay |
| `--sender` | ✅ | Signing wallet |
| `--json` | ✅ | Machine-parseable output |

### `aave withdraw`

| Param | Required | Description |
|-------|----------|-------------|
| `--asset` | ✅ | Token symbol to withdraw |
| `--amount` | ✅ | Amount to withdraw, or `max` for full balance |
| `--to` | ✅ | Destination wallet address |
| `--sender` | ✅ | Signing wallet |
| `--json` | ✅ | Machine-parseable output |

### `aave set-collateral`

| Param | Required | Description |
|-------|----------|-------------|
| `--asset` | ✅ | The supplied asset to enable/disable as collateral |
| `--user` | ✅ | Wallet address (must match `--sender` — operates on `msg.sender`) |
| `--sender` | ✅ | Signing wallet — MUST be `--user` itself |
| `--json` | ✅ | Machine-parseable output |

### `aave positions`

| Param | Required | Description |
|-------|----------|-------------|
| `--user` | ✅ | Wallet address to query |
| `--json` | ✅ | Machine-parseable output |
