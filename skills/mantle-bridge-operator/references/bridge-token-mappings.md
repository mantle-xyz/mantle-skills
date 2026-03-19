# Bridge Token Mappings

## Native Assets

| Asset | L1 Address (Ethereum) | L2 Address (Mantle) | Notes |
|-------|----------------------|---------------------|-------|
| ETH | native | `0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111` (WETH) | ETH is wrapped on L2 |
| MNT | `0x3c3a81e81dc49A522a592e7622A7E711c06bf354` | native | MNT is the L2 gas token |

## Bridged ERC-20 Tokens

| Token | L1 Address (Ethereum) | L2 Address (Mantle) | Decimals |
|-------|----------------------|---------------------|----------|
| USDC | Verify on token-list.mantle.xyz | `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9` | 6 |
| USDT | Verify on token-list.mantle.xyz | `0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE` | 6 |
| mETH | — | `0xcDA86A272531e8640cD7F1a92c01839911B90bb0` | 18 |
| cmETH | — | `0xE6829d9a7eE3040e1276Fa75293Bde931859e8fA` | 18 |

## Bridge Contracts

| Contract | Network | Address |
|----------|---------|---------|
| L1 Standard Bridge | Ethereum | `0x95fC37A27a2f68e3A647CDc081F0A89bb47c3012` |
| L2 Standard Bridge | Mantle | `0x4200000000000000000000000000000000000010` |
| L2 Cross-Domain Messenger | Mantle | `0x4200000000000000000000000000000000000007` |
| L2 to L1 Message Passer | Mantle | `0x4200000000000000000000000000000000000016` |

## Verification Rules

- Always verify L1 token addresses against the canonical source before recommending a bridge operation. Use `https://token-list.mantle.xyz` as the primary reference.
- Use `mantle_resolveToken` to confirm the L2 address.
- If a token's L1 address cannot be verified, mark the bridge plan as `blocked` and ask the user to confirm the address.

## Unsupported Token Types

The following token types are NOT compatible with the Standard Bridge:
- Fee-on-transfer tokens (tokens that deduct a fee on every transfer)
- Rebasing tokens (tokens that change balances without Transfer events)
- Tokens without a corresponding `OptimismMintableERC20` on the destination chain
