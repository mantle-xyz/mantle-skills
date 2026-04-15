# Swap Workflow

Load this file the first time you execute a swap in a session, or when handling retries / timeouts / wrap-mnt edge cases.

## Pre-condition

You have the input token in your wallet. For MNT, wrap to WMNT first (see below).

## Token → Token

```
1. mantle-cli swap pairs --json
   → Find the pair and its params (bin_step or fee_tier)

2. mantle-cli defi swap-quote --in X --out Y --amount 10 --provider best --json
   → Get the expected output and minimum_out_raw

3. mantle-cli account allowances <wallet> --pairs X:<router> --json
   → Check if already approved

4. IF allowance < amount:
   mantle-cli approve --token X --spender <router> --amount <amount> --json
   → Sign and broadcast → WAIT for confirmation

5. mantle-cli swap build-swap \
     --provider <dex> \
     --in X --out Y --amount 10 \
     --recipient <wallet> \
     --amount-out-min <from_quote> \
     --sender <wallet> \
     --json
   → Sign and broadcast → WAIT for confirmation
```

## MNT → Token

MNT is the native gas token. Wrap first, then swap WMNT.

```
1. mantle-cli swap wrap-mnt --amount <n> --json   → sign & WAIT
2. mantle-cli defi swap-quote --in WMNT --out X --amount <n> --json
3. mantle-cli account allowances <wallet> --pairs WMNT:<router> --json
4. IF insufficient: mantle-cli approve ...        → sign & WAIT
5. mantle-cli swap build-swap ...                  → sign & WAIT
```

## Token → MNT

Swap to WMNT, then unwrap:

```
... (Token → Token steps with --out WMNT) ...
N+1. mantle-cli swap unwrap-mnt --amount <n> --json   → sign & WAIT
```

## Critical rules

- **Always pass `--sender <wallet>`** to build-swap so the response carries an `idempotency_key` scoped to the signer.
- **NEVER call build-swap twice for the same buy** — re-broadcasting causes duplicate swaps. If the previous call timed out, check `mantle-cli chain tx --hash <hash> --json` first.
- **NEVER set `allow_zero_min`** in production. Always pass `amount_out_min` from the quote response. Swaps without slippage protection are vulnerable to sandwich attacks.
- **"sign & WAIT"** means wait for `status: success` from `mantle-cli chain tx --hash <hash> --json` before building the next tx. Do NOT pipeline unsigned transactions.
- **Show `human_summary`** from every build response to the user before they sign.
- **Quote impact check** — abort if `priceImpactPct > 1%`, warn if > 0.2%.

## "MNT" is not a swap input

Do NOT pass `MNT` to `swap`/`approve`/`lp` commands — those expect WMNT (the ERC-20). To convert between MNT and WMNT, use `swap wrap-mnt` / `swap unwrap-mnt`. Moving MNT (or any other token) between wallets is NOT supported — refuse transfer requests rather than attempting a utils-based workaround.
