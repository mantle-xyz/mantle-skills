# Third-Party Bridges

## When to Consider

The native Mantle bridge is free but slow for L2-to-L1 withdrawals (12+ hours). Third-party bridges offer faster cross-chain transfers at a cost. Recommend them when:

- User needs funds on L1 within minutes, not hours.
- User is bridging between Mantle and a non-Ethereum chain (e.g., Arbitrum, Polygon).
- User wants to compare cost vs speed tradeoffs.

## Verified Bridges with Mantle Support

| Bridge | Speed | Fee | Supported Routes | Trust Model |
|--------|-------|-----|-----------------|-------------|
| Stargate (LayerZero) | 1-5 min | Low (dynamic) | ETH, USDC, USDT + multi-chain | Relayer + oracle |
| Orbiter Finance | 1-10 min | Flat ~0.001-0.01 ETH | ETH, USDC, USDT | Maker network |
| Across Protocol | 1-5 min | 0.06%-0.12% | ETH, USDC, WETH | UMA optimistic oracle |
| Celer cBridge | 2-10 min | 0.1%-0.3% | ETH, USDC, USDT + 40 chains | SGN validator network |

## Comparison Template

When comparing bridges for a user request:

1. Check native bridge cost from `bridge-fee-guide.md`.
2. Note the 12-hour withdrawal delay for native L2-to-L1.
3. For each third-party option:
   - Confirm it supports the requested token and route.
   - Note the fee (percentage or flat).
   - Note the speed.
   - Note the trust model.
4. Present as a ranked table: cheapest first for cost-sensitive users, fastest first for time-sensitive users.

## Safety Rules

- Third-party bridges are NOT part of the Mantle canonical bridge. They carry independent smart contract risk.
- Never present third-party bridge addresses as verified Mantle registry entries.
- If a third-party bridge is not in this list, do not recommend it without explicit user confirmation.
- Always note that third-party bridges may have liquidity limits — large transfers may face slippage or partial fills.
- For amounts over $100K, recommend the native bridge for security, even with the delay.
