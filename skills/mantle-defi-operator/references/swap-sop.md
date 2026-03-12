# Swap SOP

Use this standard flow for token swap pre-execution analysis on Mantle.

## Step 1: Normalize input

- token in/out addresses
- exact input amount or exact output target
- recipient address
- slippage cap and deadline

## Step 2: Select candidate protocol

- Start with curated defaults: `Merchant Moe`, `Agni`.
- Resolve the execution-ready router/quoter from `mantle-address-registry-navigator`.
- If the user names another venue, verify its contracts before comparing it.
- Record whether live ranking inputs were fresh enough to influence ordering.

## Step 3: Token metadata

- Fetch decimals and symbol for token in/out.
- Convert user amount to raw units.

## Step 4: Quote and route

- Query the best verified candidate route first, then compare `also_viable` venues when needed.
- Capture expected output and minimum output after slippage.
- Record quote timestamp and source.
- If metrics are unavailable, keep the curated default first and note reduced confidence.

## Step 5: Allowance check

- Read current allowance for spender/router.
- If insufficient:
  - prepare approval for minimum required amount
  - note whether external executor can safely batch approve+swap

## Step 6: Build execution handoff plan

- Build a deterministic call sequence (approve if needed, then swap).
- Include router/spender, raw amounts, recipient, deadline, slippage-bound minimum output, and the registry key used for the selected router.
- State explicitly that execution must happen in an external signer/wallet flow.

## Step 7: Post-execution verification plan

- Define which balances and allowances to re-read after user-confirmed execution.
- Compare observed output versus expected minimum once execution evidence is provided.
- Report slippage/anomalies as pending until post-execution data is available.
