# Liquidity SOP

Use this flow for add/remove liquidity pre-execution analysis.

## Candidate venue selection

1. Start with curated defaults: `Merchant Moe`, `Agni`.
2. Resolve the required router, quoter, or position manager from `mantle-address-registry-navigator`.
3. Rank candidate venues by TVL, recent volume, pool fit, and operational complexity.
4. If live metrics are stale or unavailable, keep the curated default first and call out lower confidence.
5. Treat unverified venues as `discovery_only`, not execution-ready targets.

## Add liquidity (planning)

1. Resolve pool address, token pair, and registry-backed execution contracts.
2. Fetch token decimals, reserves, and share math context.
3. Compute desired token amounts and min LP shares expected.
4. Check allowances for both tokens.
5. Determine whether approval(s) are required and specify minimum scope.
6. Prepare add-liquidity call parameters, selected venue rationale, and sequencing for external execution.
7. Add post-execution checks for LP tokens received.

## Remove liquidity (planning)

1. Resolve pool, LP token details, and registry-backed execution contracts.
2. Read LP balance and allowance for pool/router.
3. Compute expected token outputs and minimums.
4. Determine whether LP approval is required and specify minimum scope.
5. Prepare remove-liquidity call parameters, selected venue rationale, and sequencing for external execution.
6. Add post-execution checks for underlying assets received.

## Post-operation verification plan

- Define final wallet balances to re-check for all affected tokens after user-confirmed execution.
- Compare expected vs actual outputs once execution evidence is provided.
- Flag high slippage, shortfall, or unexpected extra fees as pending/observed.
