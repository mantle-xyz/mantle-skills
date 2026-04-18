# Swap Workflow

Load this file the first time you execute a swap in a session, or when handling retries / timeouts / wrap-mnt edge cases.

> **⚠ Steps MUST be executed in strict sequential order (Rule W-1). NEVER skip a step or jump ahead. Each transaction requires user confirmation (Rule W-2).**

## ⛔⛔⛔ CALLDATA INTEGRITY — READ BEFORE EVERY `build-swap` / `wrap-mnt` / `unwrap-mnt` / `approve` SIGN CALL

**See SUPREME RULE in `SKILL.md`.** `mantle-cli swap build-swap` returns an `unsigned_tx` whose `data` field is typically 500–2000+ hex chars (Agni/Fluxion router calls are especially long). Every one of those chars MUST reach the Privy signer unchanged.

Before calling the signer on any swap tx, run the 5-question pre-sign verification protocol from `SKILL.md` SUPREME RULE:

1. Raw `mantle-cli` JSON still available? If not, STOP and rebuild.
2. `data` identical to CLI output — same first 16 chars, same last 16 chars, same total length, NO `…` / `...` / `<snip>` / `[truncated]`, NO line wraps, NO inserted whitespace?
3. `to` (router address) identical to CLI output?
4. `value` (hex wei) identical to CLI output?
5. `--amount-out-min` you passed to the build call is an EXACT substring of the quote's `minimum_out_raw` — no `9_934_699`, no `9.93e6`, no rounding, no "simplified" form?

If any answer is NO or UNKNOWN, abort. Do NOT sign a swap with edited calldata — the trade will either revert (wasted gas + idempotency_key consumed) or route to an unintended function with your funds as input.

**Most common truncation points in swap flows:**
- `build-swap` returns a long multi-hop router call — `data` clipped mid-message → revert or wrong-call.
- `minimum_out_raw` silently reformatted (underscore separators, decimal form) → the build rejects it or, worse, accepts a lower value → sandwich risk.
- `router` address rewritten from memory (Agni vs Fluxion vs Merchant Moe) → tokens sent to the wrong router → potentially locked.

## 🛑 STEP 0 — Parse the user's intent FIRST (Rule W-5)

**Before touching any CLI command, determine whether the number attaches to the INPUT or the OUTPUT side.** Getting this wrong silently swaps who pays what — an unrecoverable misroute of funds.

| User phrasing | Input | Output | Mode |
|---|---|---|---|
| "swap **10 MNT** for USDC" | **10 MNT (fixed)** | variable USDC | fixed-input |
| "swap MNT for **10 USDC**" / "swap me **10 USDC** using MNT" | variable MNT | **10 USDC (fixed)** | fixed-output |
| "buy **10 USDC** with MNT" / "pay with MNT, give me **10 USDC**" | variable MNT | **10 USDC (fixed)** | fixed-output |

**Rule:** the numeric quantity attaches to whichever token it is **directly adjacent to** in the sentence — never flip it. The rule is language-agnostic: the same logic applies to English, Chinese, or any other phrasing. Translate the user's request into the canonical form `swap <input_token> for <output_token>` with the number on the side where the user placed it.

### Incident (2026-04): agent misread "swap MNT for 0.5 USDC"

- User intent: **output = 0.5 USDC** (fixed-output, variable MNT input)
- Agent action: `mantle-cli swap wrap-mnt --amount 0.5` (treated 0.5 as MNT input) ❌
- Correct action: reverse-quote to find MNT needed for 0.5 USDC output, or ask the user for the MNT input amount. Do NOT wrap 0.5 MNT.

### Handling fixed-output requests

`mantle-cli swap build-swap` is **fixed-input** (`--amount` is the input amount; `--amount-out-min` is a slippage floor, not a target). For fixed-output requests:

1. **Reverse-quote** with `mantle-cli defi swap-quote --in X --out Y --exact-out <N> --json` IF the CLI supports `--exact-out`. Verify via `mantle-cli catalog show mantle_swapQuote --json` before using.
2. If `--exact-out` is not supported, **STOP and ask the user for the input amount.** Do NOT silently convert the output quantity into an input quantity. Do NOT guess.
3. Never start `wrap-mnt`, `approve`, or `build-swap` until the direction is resolved and the user has confirmed the input amount (via Rule W-2).

## 🛑 STEP 0.5 — Pre-Execution Readiness Check (Rule W-9)

**The readiness check is per-operation, not per-workflow.** Every `mantle-cli` write op (`wrap-mnt`, `unwrap-mnt`, `approve`, `build-swap`) needs the checks that are actually applicable to it. Allowance does NOT apply to native-MNT operations (no ERC-20 allowance on the native asset) or to unwrap (burns WMNT held by the caller).

**Operation matrix:**

| Write op | Balance check | Allowance check |
|---|---|---|
| `swap wrap-mnt --amount N` | native MNT ≥ N (+ gas headroom) via `account token-balances` | **N/A** — native asset, no allowance |
| `swap unwrap-mnt --amount N` | WMNT ≥ N via `account token-balances` | **N/A** — caller burns own WMNT |
| `approve --token X --spender <router>` | **N/A** — no funds move | **N/A** — this IS the allowance fix |
| `swap build-swap --in X --amount N --sender <wallet>` | `X` balance ≥ N via `account token-balances` | `X:<router>` allowance ≥ N via `account allowances` |

Queries (run BEFORE the Transaction Confirmation Summary so the summary reflects real on-chain state):

- **Balance** — `mantle-cli account token-balances <wallet> --json`. Insufficient → **STOP**, tell the user the actual balance, do NOT proceed.
- **Allowance** — `mantle-cli account allowances <wallet> --pairs <input_token>:<router> --json`. Insufficient → route to the approve flow (Rule W-6). Do NOT silently skip.

Skipping an applicable check is a hard error. Running a check that is marked N/A is wasted effort, not a violation.

### MNT → Token ordering note

On the MNT → Token path the router is not known until the WMNT quote in Step 2, so the pre-`wrap-mnt` check CANNOT include a WMNT:router allowance check — the router does not exist yet. Split the readiness gate in two:

1. **Before `wrap-mnt`**: native MNT balance check only (per the matrix above).
2. **After the Step 2 quote, before `approve` / `build-swap`**: WMNT balance ≥ wrapped amount AND WMNT:`<router from quote>` allowance ≥ amount.

Do not invent a router address to satisfy the gate, and do not skip the second check after wrapping.

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
>
> **⛔ STEP 0.5 is split on this path** (see "MNT → Token ordering note" above): native-MNT balance check BEFORE Step 1's `wrap-mnt`; WMNT balance + WMNT:`<router>` allowance check AFTER Step 2's quote, BEFORE Step 4's `approve` / Step 5's `build-swap`. Do not invent a router to run the allowance check before the quote.

```
0a. mantle-cli account token-balances <wallet> --json
    → Verify native MNT balance ≥ (wrap amount + gas headroom). Insufficient → STOP.
    ↓ MUST complete before Step 1

1. ⚠️ USER CONFIRMATION — present wrap details (amount of MNT to wrap — this is the INPUT amount, resolved in Step 0)
   mantle-cli swap wrap-mnt --amount <n> --json   → sign & WAIT
   ↓ MUST confirm tx success before Step 2
2. mantle-cli defi swap-quote --in WMNT --out X --amount <n> --json
   → Capture `router` and `minimum_out_raw` from the response.
   ↓ MUST complete before Step 3
3. mantle-cli account token-balances <wallet> --json
   → Verify WMNT balance ≥ <n>. Then:
   mantle-cli account allowances <wallet> --pairs WMNT:<router> --json
   → Verify allowance ≥ <n>. Insufficient → continue to Step 4. Sufficient → skip to Step 5.
   ↓ MUST complete before Step 4
4. IF insufficient: ⚠️ USER CONFIRMATION → mantle-cli approve --token WMNT --spender <router> --amount <n> --json → sign & WAIT
   ↓ MUST confirm tx success before Step 5
5. ⚠️ USER CONFIRMATION — present full Transaction Confirmation Summary
   mantle-cli swap build-swap --in WMNT --out X --amount <n> --recipient <wallet> --amount-out-min <minimum_out_raw> --sender <wallet> --json
   → sign & WAIT
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
