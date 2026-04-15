# Lending SOP

Use this standard flow for Aave V3 lending operations (supply, borrow, repay, withdraw) on Mantle.

## ⚠ CRITICAL: supply is NOT a token transfer

`mantle-cli aave supply` calls the Aave `Pool.supply()` function. Internally the Pool pulls tokens from the user via `transferFrom` AND mints aTokens that represent the deposit. An aToken balance is the only on-chain record that can be redeemed via `withdraw`.

**Never "simulate" a supply by sending tokens to the Pool address.** A plain ERC-20 `transfer()` to `0x458F293454fE0d67EC0655f3672301301DD51422` (Aave V3 Pool) does NOT trigger Pool accounting — no aToken is minted, no collateral is recorded, and the tokens are **permanently locked** in the Pool contract with no on-chain path to recover them.

| Operation | Correct command | Result |
|-----------|-----------------|--------|
| Supply (deposit) | `mantle-cli aave supply --asset USDC --amount 150 --on-behalf-of <wallet>` | aUSDC minted, redeemable via `withdraw` |
| Anti-pattern (DO NOT USE) | `mantle-cli utils encode-call --abi 'function transfer(address,uint256)' ...` targeting the Pool | Tokens locked forever — no recovery |

Red-flag patterns that indicate an incorrect supply plan:

- The plan includes a `transfer(address,uint256)` calldata whose first argument is the Aave Pool address.
- The plan routes `supply` through `mantle-cli utils encode-call` / `mantle-cli utils build-tx` rather than `mantle-cli aave supply`.
- The plan presents "send USDC to Aave Pool" as equivalent to "supply USDC to Aave". These are different operations with different end states.
- The plan omits `--on-behalf-of` and tries to avoid asking the user for their wallet address by substituting a plain transfer. **ALWAYS ask for the wallet address when it is missing** — never degrade to a plain transfer to avoid an extra round-trip.

If a user request maps to supply / borrow / repay / withdraw, use the dedicated `mantle-cli aave …` command. If a user asks to "transfer tokens to Aave" in natural language, clarify with them that this means `supply`, and use the correct command. Token transfers between wallets are out of scope for this skill (see SKILL.md guardrails).

## CRITICAL: Use CLI for Transaction Building

**ALWAYS use `mantle-cli` to build unsigned transactions.** Do NOT manually construct calldata, extract addresses from text, or build approve calls yourself. The CLI handles address resolution, ABI encoding, and whitelist validation correctly.

```bash
# All commands support --json for structured output
mantle-cli aave supply          --asset USDC --amount 1.0 --on-behalf-of 0x... --json
mantle-cli aave set-collateral  --asset WMNT --user 0x... --json  # enable collateral (diagnostics)
mantle-cli aave borrow          --asset USDC --amount 0.5 --on-behalf-of 0x... --json
mantle-cli aave repay           --asset USDC --amount 0.5 --on-behalf-of 0x... --json
mantle-cli aave repay           --asset USDC --amount max --on-behalf-of 0x... --json
mantle-cli aave withdraw        --asset USDC --amount 1.0 --to 0x... --json
mantle-cli aave withdraw        --asset USDC --amount max --to 0x... --json
mantle-cli aave positions       --user 0x... --json  # check positions + collateral flags
mantle-cli aave markets         --json  # check APY/TVL before deciding
```

For approvals (required before supply/repay):
```bash
mantle-cli approve --token USDC --spender 0x458F293454fE0d67EC0655f3672301301DD51422 --amount max --json
```

The CLI outputs `unsigned_tx` with `to`, `data`, `value`, `chainId` — **no `from` field**. Pass this directly to the signer without modification.

## Step 1: Check lending markets

```bash
mantle-cli aave markets --json
```

- Review supply APY, borrow APY, TVL, LTV, and liquidation threshold.
- Confirm the target asset is a supported Aave V3 reserve.
- Supported assets: WETH, WMNT, USDT0, USDC, USDe, sUSDe, FBTC, syrupUSDT, wrsETH, GHO.
- **IMPORTANT:** Only USDT0 is supported on Aave V3, NOT USDT. If the user holds USDT, they must swap USDT → USDT0 on Merchant Moe first (USDT/USDT0 pool, bin_step=1).

## Step 2: Normalize input

- Asset symbol or address
- Amount (decimal, or `max` for repay/withdraw)
- Wallet address (on_behalf_of for supply/borrow/repay, to for withdraw)

## Isolation Mode

Some Aave V3 reserves are **Isolation Mode assets** — when a user's ONLY collateral
is an Isolation Mode asset, the user enters Isolation Mode which restricts borrowing.

### Isolation Mode assets on Mantle

| Asset | Isolation Mode | Debt Ceiling |
|-------|:-:|---:|
| WETH | Yes | $30,000,000 |
| WMNT | Yes | $2,000,000 |
| All others | No | — |

### Assets borrowable in Isolation Mode

| Asset | Borrowable in Isolation |
|-------|:-:|
| USDC | Yes |
| USDT0 | Yes |
| USDe | Yes |
| GHO | Yes |
| sUSDe, FBTC, WETH, WMNT, syrupUSDT, wrsETH | **No** |

### Rules

- If the user only has WETH or WMNT as collateral → they are in Isolation Mode
- In Isolation Mode, **only** USDC, USDT0, USDe, GHO can be borrowed
- Total debt across all isolation-mode borrowers is capped by the debt ceiling
- Error `UserInIsolationModeOrLtvZero` (0x5b263df7) = tried to borrow a non-whitelisted asset in Isolation Mode

### Before building a borrow transaction

1. **Check what collateral the user has supplied** (aToken balances or `getUserAccountData`)
2. If collateral is ONLY an isolation-mode asset → they are in Isolation Mode
3. Verify the borrowed asset has `borrowableInIsolation = true`
4. If the user wants to borrow a non-isolation asset (e.g. sUSDe), they must add non-isolation collateral (e.g. USDC) first

## Step 3: Check balance and allowance

```bash
mantle-cli account balance <wallet> --tokens USDC,USDT0 --json
```

- Verify the wallet has sufficient token balance for supply/repay.
- The Aave Pool address is `0x458F293454fE0d67EC0655f3672301301DD51422`.

## Step 4: Approve if needed

If allowance is insufficient for supply or repay:

```bash
mantle-cli approve --token USDC \
  --spender 0x458F293454fE0d67EC0655f3672301301DD51422 \
  --amount <exact_or_max> --owner <wallet> --json
```

- The CLI validates the spender against the whitelist.
- Use `--owner` to check existing allowance and skip if already sufficient.
- Sign and broadcast the approve `unsigned_tx` before proceeding to supply/repay.

## Step 5: Build the lending transaction

Use the appropriate CLI command:

| Operation | Command | Key flags |
|-----------|---------|-----------|
| Deposit | `mantle-cli aave supply` | `--asset`, `--amount`, `--on-behalf-of` |
| Borrow | `mantle-cli aave borrow` | `--asset`, `--amount`, `--on-behalf-of`, `--interest-rate-mode` |
| Repay | `mantle-cli aave repay` | `--asset`, `--amount` (or `max`), `--on-behalf-of` |
| Withdraw | `mantle-cli aave withdraw` | `--asset`, `--amount` (or `max`), `--to` |

Always use `--json` to get structured output for the signer.

## Step 5b: Verify and enable collateral (before borrowing)

After supplying an asset, Aave V3 normally auto-enables it as collateral. However, this auto-enablement can fail (especially for Isolation Mode assets like WMNT/WETH). **Before attempting a borrow, always verify collateral status.**

### Check positions

```bash
mantle-cli aave positions --user <wallet> --json
```

- Check the `collateral_enabled` field for the supplied asset (YES / NO)
- Check `total_collateral_usd` > 0 in the account summary
- If `collateral_enabled` is NO and `total_collateral_usd` is 0: collateral was NOT auto-enabled

### Diagnose and fix with set-collateral

```bash
# Use the actual asset that was supplied and needs collateral enabled — NOT always WMNT.
# Identify it from the positions output: the reserve with supplied > 0 and collateral_enabled=NO.
mantle-cli aave set-collateral --asset <supplied_asset> --user <wallet> --json
```

This tool runs **preflight diagnostics** before building the transaction:

| Check | Failure | Meaning |
|-------|---------|---------|
| aToken balance | `NO_SUPPLY_BALANCE` | User hasn't supplied this asset — supply first |
| Reserve active | `RESERVE_NOT_ACTIVE` | Reserve deactivated by governance — cannot use |
| Reserve LTV | `LTV_IS_ZERO` | LTV=0 on-chain — this asset **cannot** be collateral (root cause is governance config, not the collateral flag). Do NOT attempt to set-collateral; it is designed this way. |
| Reserve frozen | Warning | Supply/borrow frozen but collateral toggle may work |
| Collateral already enabled | `NO-OP` warning | Flag already set — borrow failure has a different root cause (likely oracle pricing) |

**Important:** The `--user` flag is for diagnostics only. The actual transaction operates on `msg.sender` (the signing wallet). The signing wallet MUST be the same address as `<wallet>` — otherwise collateral will be toggled on the wrong account.

If diagnostics show collateral is NOT enabled and LTV > 0:
1. Sign and broadcast the `set-collateral` unsigned_tx (signer must be `<wallet>`)
2. Re-check positions to confirm `collateral_enabled` is now YES
3. Proceed to borrow

## Step 6: Sign and broadcast

- Pass the `unsigned_tx` object directly to the external signer.
- **Do NOT add a `from` field** — the signer determines `from` from the signing key.
- **Do NOT modify `to`, `data`, `value`, or `chainId`** fields.

## Step 7: Post-execution verification

- Re-read token balance and aToken balance to confirm the operation.
- For supply: verify aToken balance increased **and check `collateral_enabled` in positions output**.
- For set-collateral: verify `collateral_enabled` changed and `total_collateral_usd` > 0.
- For borrow: verify token balance increased and debt token appeared.
- For repay: verify debt token balance decreased.
- For withdraw: verify aToken balance decreased and token balance increased.
- Check health factor after borrow/withdraw to ensure it remains above 1.0.

## Common pitfalls

- **Modelling supply as a plain transfer**: The #1 cause of permanent fund loss. ERC-20 `transfer()` to the Aave Pool address mints NO aToken — the tokens are locked forever. Always use `mantle-cli aave supply`. Never route Aave supply through `mantle-cli utils encode-call` / `mantle-cli utils build-tx`.
- **Missing approve**: supply and repay require prior ERC-20 approval for the Aave Pool.
- **Missing collateral enablement**: after supply, always verify `collateral_enabled=YES` before borrowing. If it's NO, use `set-collateral` to enable. If `set-collateral` throws `LTV_IS_ZERO`, the asset cannot be used as collateral by governance design.
- **`from` field in unsigned_tx**: NEVER add `from` — this breaks Privy and some signers.
- **Stale allowance**: use `--owner` flag in approve to auto-skip if sufficient.
- **Health factor**: borrow and withdraw reduce health factor — check before proceeding.
- **`max` semantics**: repay max repays full debt; withdraw max withdraws full balance.
- **Isolation Mode**: WETH and WMNT are Isolation Mode assets. If a user's only collateral is one of these, they can ONLY borrow USDC, USDT0, USDe, or GHO. Attempting to borrow other assets will revert with `UserInIsolationModeOrLtvZero`. Always check collateral type before building a borrow transaction.
