# Swap SOP

Use this standard flow for token swap pre-execution analysis on Mantle.

## CRITICAL: Use CLI for Transaction Building

**ALWAYS use `mantle-cli` to build unsigned transactions.** Do NOT manually construct calldata, extract addresses from text, or build approve calls yourself. The CLI handles address resolution, ABI encoding, pool parameter lookup, and whitelist validation correctly.

```bash
# Get swap quote first
mantle-cli defi swap-quote --in USDC --out WMNT --amount 10 --provider best --json

# Build the swap transaction
mantle-cli swap build-swap --provider agni --in USDC --out WMNT \
  --amount 10 --recipient 0x... --json

# If approval is needed
mantle-cli swap approve --token USDC --spender <router_address> \
  --amount <exact_or_max> --owner <wallet> --json

# Check available pairs and pool parameters
mantle-cli swap pairs --provider merchant_moe --json
```

The CLI outputs `unsigned_tx` with `to`, `data`, `value`, `chainId` — **no `from` field**. Pass this directly to the signer without modification.

## Step 1: Normalize input

- token in/out symbols or addresses
- exact input amount or exact output target
- recipient address
- slippage cap and deadline

## Step 2: Select candidate protocol

- Start with curated defaults: `Merchant Moe`, `Agni`, `Fluxion`.
- Use `mantle-cli swap pairs --json` to check available pairs and pool parameters per DEX.
- Resolve the execution-ready router/quoter from `mantle-address-registry-navigator`.
- If the user names another venue, verify its contracts before comparing it.
- Record whether live ranking inputs were fresh enough to influence ordering.

## Step 3: Token metadata

- Fetch decimals and symbol for token in/out.
- For tokens in the registry, use their symbol directly.
- For unknown tokens, pass the contract address — the CLI resolves decimals on-chain.
- Convert user amount to raw units.

## Step 4: Quote and route

```bash
mantle-cli defi swap-quote --in <token> --out <token> --amount <amount> --provider best --json
```

- Query the best verified candidate route first, then compare `also_viable` venues when needed.
- Capture expected output and minimum output after slippage.
- Record quote timestamp and source.
- If metrics are unavailable, keep the curated default first and note reduced confidence.

## Step 5: Allowance check

- Read current allowance for spender/router.
- If insufficient:
  ```bash
  mantle-cli swap approve --token <token> --spender <router> --amount <amount> --owner <wallet> --json
  ```
  - The CLI validates the spender against the whitelist.
  - Use `--owner` to check existing allowance and skip if sufficient.
  - Note whether external executor can safely batch approve+swap.

## Step 6: Build execution handoff plan

```bash
mantle-cli swap build-swap --provider <dex> --in <token> --out <token> \
  --amount <amount> --recipient <wallet> --json
```

- The CLI returns a deterministic `unsigned_tx` with correct ABI encoding.
- **Do NOT add a `from` field** — the signer determines `from` from the signing key.
- **Do NOT modify `to`, `data`, `value`, or `chainId`** fields.
- State explicitly that execution must happen in an external signer/wallet flow.

## Step 7: Post-execution verification plan

- Define which balances and allowances to re-read after user-confirmed execution.
- Compare observed output versus expected minimum once execution evidence is provided.
- Report slippage/anomalies as pending until post-execution data is available.

## Common pitfalls

- **`from` field in unsigned_tx**: NEVER add `from` — this breaks Privy and some signers.
- **Wrong pool parameters**: always let the CLI resolve `fee_tier` / `bin_step` from the pair registry; only specify manually for unknown pairs.
- **Merchant Moe version enum**: the CLI handles this correctly (V1=0, V2.2=3); do NOT override.
- **Missing approve**: swaps require prior ERC-20 approval for the router contract.
