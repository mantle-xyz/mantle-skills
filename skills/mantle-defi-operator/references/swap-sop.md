# Swap SOP

Use this standard flow for token swap pre-execution analysis on Mantle.

## CRITICAL: Use CLI for Transaction Building

**ALWAYS use `mantle-cli` to build unsigned transactions.** Do NOT manually construct calldata, extract addresses from text, or build approve calls yourself. The CLI handles address resolution, ABI encoding, pool parameter lookup, multi-hop routing, and whitelist validation correctly.

```bash
# Build the swap transaction — works for both direct and multi-hop routes
mantle-cli swap build-swap --provider fluxion --in WMNT --out BSB \
  --amount 0.5 --recipient 0x... --json

# If approval is needed
mantle-cli approve --token WMNT --spender <router_address> \
  --amount <exact_or_max> --owner <wallet> --json

# Check available pairs and pool parameters
mantle-cli swap pairs --provider fluxion --json
```

The CLI outputs `unsigned_tx` with `to`, `data`, `value`, `chainId` — **no `from` field**. Pass this directly to the signer without modification.

## Multi-hop Routing (Built-in)

The CLI **automatically discovers multi-hop routes** when no direct pair exists. You do NOT need to find intermediate pools or build multi-step swaps yourself.

**How it works:** when `--in A --out B` has no direct pool, the CLI tries 2-hop paths via bridge tokens (WMNT, USDC, USDT0, USDT, USDe, WETH) using the registered pair registry. If a route `A → bridge → B` exists, it builds a single `exactInput` (V3) or multi-token-path (Merchant Moe) transaction.

**Examples of auto-routed swaps:**

```bash
# WMNT → BSB  (auto-routes: WMNT → USDT0 → BSB on Fluxion)
mantle-cli swap build-swap --provider fluxion --in WMNT --out BSB --amount 0.5 --recipient 0x... --json

# WMNT → wTSLAx  (auto-routes: WMNT → USDC → wTSLAx on Fluxion)
mantle-cli swap build-swap --provider fluxion --in WMNT --out wTSLAx --amount 0.5 --recipient 0x... --json

# WMNT → ELSA  (auto-routes: WMNT → USDT0 → ELSA on Fluxion)
mantle-cli swap build-swap --provider fluxion --in WMNT --out ELSA --amount 0.5 --recipient 0x... --json
```

**What you MUST NOT do:**
- Do NOT manually split a swap into two separate transactions (e.g. WMNT→USDT0 then USDT0→BSB). The CLI handles this as a single atomic multi-hop transaction with better gas efficiency.
- Do NOT search for intermediate pools or bridge tokens yourself. The CLI's route discovery uses the verified pair registry.
- Do NOT use aggregators or external routing services. Only use `mantle-cli swap build-swap`.

**When multi-hop is used**, the response will show:
- `intent: "swap_multihop"` (instead of `"swap"`)
- `human_summary` shows the full path (e.g. "Swap 0.5 WMNT → BSB via WMNT → USDT0 → BSB on Fluxion")
- `warnings` include the route details and fee tiers

## USDT vs USDT0

Mantle has two official USDT variants — both are legitimate and have deep DEX liquidity:
- **USDT** (`0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE`) — bridged Tether, active on Merchant Moe and other DEXes.
- **USDT0** (`0x779Ded0c9e1022225f8E0630b35a9b54bE713736`) — LayerZero OFT Tether, active on DEXes AND Aave V3.

When a user says "USDT", clarify which one they mean if context doesn't make it clear. A direct USDT/USDT0 pool (bin_step=1) exists on Merchant Moe for conversion between the two.

## Step 1: Normalize input

- token in/out symbols or addresses
- exact input amount
- recipient address
- slippage cap (default 0.5%)

## Step 2: Get a swap quote (REQUIRED)

```bash
mantle-cli defi swap-quote --in <token_in> --out <token_out> \
  --amount <amount> --provider best --json
```

This returns:
- `provider`: the DEX with the best output for this pair
- `minimum_out_raw`: use as `--amount-out-min` in the build step
- `router_address`: use as `--spender` in the approval step
- `resolved_pool_params`: the actual `fee_tier` / `bin_step` / `pool_address` used
- `source_trace`: shows whether the quote came from `onchain:*` (primary) or `dexscreener:*` (fallback)

**CRITICAL:** Always get a quote before building. The quote provides the slippage protection value (`minimum_out_raw`) that prevents sandwich attacks. The `provider` field tells you which DEX to use for the build step.

**Quote uses on-chain quoter contracts** (Agni QuoterV2, Moe LB Quoter) as the primary source — the same data source that `build-swap` uses for pool discovery. This ensures quote and build select the same pool.

### Native MNT swaps

If the input is native MNT (not WMNT), wrap it first:
```bash
mantle-cli swap wrap-mnt --amount <n> --json
# Sign and broadcast the wrap tx
# Then use WMNT as token_in for both quote and swap
```

## Step 3: Select candidate protocol

- Use the `provider` from the quote response as your primary choice.
- For xStocks RWA tokens (wTSLAx, wAAPLx, wNVDAx, etc.) → use **Fluxion** (only DEX with these pools).
- For BSB, ELSA, VOOI → use **Fluxion** (paired with USDT0).
- If the user names another venue, verify its contracts before comparing it.

## Step 3: Token metadata

- For tokens in the registry, use their symbol directly.
- For unknown tokens, pass the contract address — the CLI resolves decimals on-chain.

## Step 5: Build the swap

```bash
mantle-cli swap build-swap --provider <provider_from_quote> \
  --in <token> --out <token> --amount <amount> \
  --recipient <wallet> \
  --amount-out-min <minimum_out_raw_from_quote> \
  --quote-provider <provider_from_quote> \
  --quote-fee-tier <fee_tier_from_resolved_pool_params> \
  --json
```

- Pass `--amount-out-min` from the quote's `minimum_out_raw` for slippage protection.
- Pass `--quote-provider` and `--quote-fee-tier` from the quote's `resolved_pool_params` — the build will emit a warning if it resolves a different pool.
- The CLI auto-discovers the best pool on-chain (fee_tier, bin_step) and auto-routes multi-hop paths via the LB Quoter.
- Check the response's `pool_params` to verify it matches the quote's `resolved_pool_params`.

## Step 6: Allowance check and approve

- The swap router address is in the `unsigned_tx.to` field of the build-swap response.
- Check if the input token is approved for that router.
- If insufficient:
  ```bash
  mantle-cli approve --token <token> --spender <router_from_tx_to> --amount <exact_or_max> --owner <wallet> --json
  ```

## Step 7: Sign and broadcast

- Pass the `unsigned_tx` object directly to the external signer.
- **Do NOT add a `from` field.**
- **Do NOT modify any fields.**

## Step 8: Post-execution verification

- Re-read balances to confirm the swap completed.
- Compare observed output versus expected.

## Common pitfalls

- **`from` field**: NEVER add `from` to unsigned_tx — breaks Privy and embedded signers.
- **Manual routing**: NEVER manually discover pools or split multi-hop into separate txs — use the CLI's built-in routing.
- **Wrong pool parameters**: NEVER manually specify `--fee-tier` or `--bin-step` for registered pairs — the CLI resolves them automatically.
- **Merchant Moe version enum**: the CLI handles this correctly (V1=0, V2.2=3); do NOT override.
- **Missing approve**: swaps require prior ERC-20 approval for the router contract.
- **Multi-hop slippage**: multi-hop routes have higher slippage risk — always get a quote first when possible.
