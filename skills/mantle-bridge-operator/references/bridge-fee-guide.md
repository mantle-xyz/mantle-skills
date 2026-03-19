# Bridge Fee Guide

## Native Mantle Bridge

The native Mantle bridge charges **no protocol fee**. Users pay only gas costs.

### L1 to L2 Deposits

| Step | Chain | Gas Token | Typical Cost |
|------|-------|-----------|-------------|
| Approve ERC-20 (if needed) | Ethereum L1 | ETH | $2-15 |
| Bridge transaction | Ethereum L1 | ETH | $5-50 |
| **Total** | | | **$7-65** |

- Cost varies with L1 congestion.
- Native ETH deposits skip the approval step.
- Deposits arrive on L2 in ~2 minutes.
- First-time Mantle users receive 1 MNT for gas on deposit.

### L2 to L1 Withdrawals

| Step | Chain | Gas Token | Typical Cost |
|------|-------|-----------|-------------|
| Initiate withdrawal | Mantle L2 | MNT | ~$0.01 |
| Wait for state root | — | — | ~60 minutes |
| Prove withdrawal | Ethereum L1 | ETH | $5-30 |
| Execution delay | — | — | 12 hours (ZK mode) |
| Finalize withdrawal | Ethereum L1 | ETH | $5-30 |
| **Total** | | | **$10-60 + 12h wait** |

- The 12-hour execution delay applies under Mantle's current ZK validity proof mode (OP Succinct/SP1).
- Legacy optimistic mode had a 7-day challenge period — some documentation may still reference this.
- Users must have ETH on L1 for the prove and finalize steps.
- Users must have MNT on L2 for the initiate step.

## Key Rules

- If the user has no MNT on L2, they cannot initiate a withdrawal. Recommend acquiring MNT first.
- If the user has no ETH on L1, they cannot prove or finalize. Warn before initiating.
- Bridge gas costs are separate from the bridged amount — they are not deducted from the transfer.
