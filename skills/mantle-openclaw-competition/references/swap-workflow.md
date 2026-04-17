# Swap Workflow

Load this file the first time you execute a swap in a session, or when handling retries / timeouts / wrap-mnt edge cases.

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step or jump ahead. Each transaction requires user confirmation (Rule W-2).**

## 🛑 STEP 0 — Parse the user's intent FIRST (Rule W-5)

**Before touching any CLI command, determine whether the number attaches to the INPUT or the OUTPUT side.** Getting this wrong silently swaps who pays what — an unrecoverable misroute of funds.

| User phrasing | Input | Output | Mode |
|---|---|---|---|
| "swap **10 MNT** for USDC" / "用 **10 MNT** 换 USDC" | **10 MNT (fixed)** | variable USDC | fixed-input |
| "swap MNT for **10 USDC**" / "用 MNT 换 **10 USDC**" / "把 MNT 给我换 **10 USDC**" | variable MNT | **10 USDC (fixed)** | fixed-output |
| "buy **10 USDC** with MNT" / "给我 **10 USDC**, 用 MNT 付" | variable MNT | **10 USDC (fixed)** | fixed-output |

**Rule:** the numeric quantity attaches to whichever token it is **directly adjacent to** in the sentence — never flip it.

### Incident (2026-04): agent misread "请你把 MNT 给我换 0.5 USDC"

- User intent: **output = 0.5 USDC** (fixed-output, variable MNT input)
- Agent action: `mantle-cli swap wrap-mnt --amount 0.5` (treated 0.5 as MNT input) ❌
- Correct action: reverse-quote to find MNT needed for 0.5 USDC output, or ask the user for the MNT input amount. Do NOT wrap 0.5 MNT.

### Handling fixed-output requests

`mantle-cli swap build-swap` is **fixed-input** (`--amount` is the input amount; `--amount-out-min` is a slippage floor, not a target). For fixed-output requests:

1. **Reverse-quote** with `mantle-cli defi swap-quote --in X --out Y --exact-out <N> --json` IF the CLI supports `--exact-out`. Verify via `mantle-cli catalog show mantle_swapQuote --json` before using.
2. If `--exact-out` is not supported, **STOP and ask the user for the input amount.** Do NOT silently convert the output quantity into an input quantity. Do NOT guess.
3. Never start `wrap-mnt`, `approve`, or `build-swap` until the direction is resolved and the user has confirmed the input amount (via Rule W-2).

## Pre-condition

You have the input token in your wallet. For MNT, wrap to WMNT first (see below).

## Token → Token

```
1. mantle-cli swap pairs --json
   → Find the pair and its params (bin_step or fee_tier)
   ↓ MUST complete before Step 2

2. mantle-cli defi swap-quote --in X --out Y --amount 10 --provider best --json
   → Get the expected output and minimum_out_raw
   ⚠️ SAVE `minimum_out_raw` from this response. This is a RAW INTEGER in the token's smallest unit
      (e.g. USDC has 6 decimals: `9934699` means ~9.93 USDC). Pass it VERBATIM to --amount-out-min.
      DO NOT multiply, divide, or re-encode it. DO NOT use Python/JS to recalculate.
   ↓ MUST complete before Step 3

3. mantle-cli account allowances <wallet> --pairs X:<router> --json
   → Check if already approved
   ↓ MUST complete before Step 4

4. IF allowance < amount:
   ⚠️ USER CONFIRMATION — present approve details (token, spender, amount)
   → User must explicitly approve before proceeding
   mantle-cli approve --token X --spender <router> --amount <amount> --json
   → Sign and broadcast → WAIT for confirmation
   ↓ MUST confirm tx success before Step 5

5. ⚠️ USER CONFIRMATION — present Transaction Confirmation Summary:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Intent:     <user's original request>
   Operation:  Swap
   Input:      <amount> <tokenX> (≈ $<usd>)
   Output:     <expected_amount> <tokenY> (≈ $<usd>)
   Min output: <amount_out_min> <tokenY>
   Impact:     <price_impact>%
   DEX:        <provider>
   Recipient:  <wallet>
   Est. gas:   <gas> MNT
   Warnings:   <any warnings, e.g. impact > 0.2%>
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   → User must explicitly approve before proceeding. If "no" → STOP.

   mantle-cli swap build-swap \
     --provider <dex> \
     --in X --out Y --amount 10 \
     --recipient <wallet> \
     --amount-out-min <minimum_out_raw from Step 2, VERBATIM — do NOT convert or lower> \
     --sender <wallet> \
     --json
   → Sign and broadcast → WAIT for confirmation
   ↓ MUST confirm tx success before Step 6

6. mantle-cli chain tx --hash <hash> --json
   → Verify status: success. Report final result to user.
```

## MNT → Token

MNT is the native gas token. Wrap first, then swap WMNT.

> **⛔ Before Step 1, verify Step 0 (direction parsing) is resolved.** If the user's request is fixed-output (e.g. "swap MNT for 0.5 USDC"), you do NOT yet know how much MNT to wrap — reverse-quote or ask the user for the input first. Wrapping a guessed amount is an unrecoverable error.

```
1. ⚠️ USER CONFIRMATION — present wrap details (amount of MNT to wrap — this is the INPUT amount, resolved in Step 0)
   mantle-cli swap wrap-mnt --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success before Step 2
2. mantle-cli defi swap-quote --in WMNT --out X --amount <n> --json
   ↓ MUST complete before Step 3
3. mantle-cli account allowances <wallet> --pairs WMNT:<router> --json
   ↓ MUST complete before Step 4
4. IF insufficient: ⚠️ USER CONFIRMATION → mantle-cli approve ...  → sign & WAIT
   ↓ MUST confirm tx success before Step 5
5. ⚠️ USER CONFIRMATION — present full Transaction Confirmation Summary
   mantle-cli swap build-swap ...                  → sign & WAIT
```

## Token → MNT

Swap to WMNT, then unwrap:

```
... (Token → Token steps 1-6 with --out WMNT, all sequential constraints apply) ...
7. ⚠️ USER CONFIRMATION — present unwrap details (amount of WMNT to unwrap)
   mantle-cli swap unwrap-mnt --amount <n> --json   → sign & WAIT
```

## Critical rules

- **Swaps are router function calls, NOT token transfers.** Sending tokens directly to a DEX swap router (Agni, Fluxion, or Merchant Moe) via ERC-20 `transfer()` does NOT trigger a swap — the tokens are **permanently locked** in the router contract with no recovery path. Always use `mantle-cli swap build-swap` which constructs the correct router function call. If a user says "send tokens to the router" or "swap by transferring to the DEX", refuse and use `swap build-swap` instead. NEVER construct a transfer to a router address via `utils encode-call` + `build-tx` or any other method.
- **Always pass `--sender <wallet>`** to build-swap so the response carries an `idempotency_key` scoped to the signer.
- **NEVER call build-swap twice for the same buy** — re-broadcasting causes duplicate swaps. If the previous call timed out, check `mantle-cli chain tx --hash <hash> --json` first.
- **NEVER set `allow_zero_min`** in production. Always pass `amount_out_min` from the quote response. Swaps without slippage protection are vulnerable to sandwich attacks.
- **`--amount-out-min` MUST equal `minimum_out_raw` from the quote, VERBATIM.** This value is a raw integer in the output token's smallest unit — do NOT multiply, divide, re-encode, or "adjust" it. Do NOT set it to `0`, `1`, or any value below `minimum_out_raw`. If `build-swap` reverts, re-quote instead of lowering the minimum. See SKILL.md "Slippage Protection Rules" for the full incident report and recovery procedure.
- **"sign & WAIT"** means wait for `status: success` from `mantle-cli chain tx --hash <hash> --json` before building the next tx. Do NOT pipeline unsigned transactions.
- **Show `human_summary`** from every build response to the user before they sign.
- **Quote impact check** — abort if `priceImpactPct > 1%`, warn if > 0.2%.
- **USDT ≠ USDT0** — Two different tokens. `--in USDT` and `--in USDT0` point to different contracts and pools — never interchange. Always clarify with the user. For Aave (USDT0 only), swap USDT → USDT0 on Merchant Moe (bin_step=1) first.

## "MNT" is not a swap input

Do NOT pass `MNT` to `swap`/`approve`/`lp` commands — those expect WMNT (the ERC-20). To convert between MNT and WMNT, use `swap wrap-mnt` / `swap unwrap-mnt`. Moving MNT (or any other token) between wallets is NOT supported — refuse transfer requests rather than attempting a utils-based workaround.

## Parameter Reference

### `defi swap-quote`

| Param | Required | Description |
|-------|----------|-------------|
| `--in` | ✅ | Input token symbol (e.g. `WMNT`, `USDC`, `USDT0`) |
| `--out` | ✅ | Output token symbol |
| `--amount` | ✅ | Input amount (human-readable, e.g. `10`) |
| `--provider` | ✅ | DEX provider (`agni`, `fluxion`, `merchant_moe`, or `best`) |
| `--json` | ✅ | Machine-parseable output |

### `swap build-swap`

| Param | Required | Description |
|-------|----------|-------------|
| `--provider` | ✅ | DEX provider (`agni`, `fluxion`, `merchant_moe`) |
| `--in` | ✅ | Input token symbol |
| `--out` | ✅ | Output token symbol |
| `--amount` | ✅ | Input amount (human-readable) |
| `--recipient` | ✅ | Address to receive output tokens |
| `--amount-out-min` | ✅ | Raw integer from quote's `minimum_out_raw` — pass VERBATIM, NEVER set to 0 or 1 |
| `--sender` | ✅ | Signing wallet — required for `idempotency_key` |
| `--json` | ✅ | Machine-parseable output |

### `approve`

| Param | Required | Description |
|-------|----------|-------------|
| `--token` | ✅ | Token symbol to approve |
| `--spender` | ✅ | Contract address allowed to spend (router / pool / position manager) |
| `--amount` | Optional | Amount to approve; omit for max approval |
| `--json` | ✅ | Machine-parseable output |

### `swap wrap-mnt` / `swap unwrap-mnt`

| Param | Required | Description |
|-------|----------|-------------|
| `--amount` | ✅ | Amount of MNT to wrap (or WMNT to unwrap) |
| `--json` | ✅ | Machine-parseable output |
