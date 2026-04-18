# Asset & Protocol Whitelist (AUTHORITATIVE)

This file is the **single source of truth** for which assets and protocol contracts may participate in any interactive / execution flow inside the OpenClaw Competition skill. Every command that plans, quotes, approves, or builds an unsigned transaction MUST reject a request that touches any asset or protocol contract outside of this list — see "Enforcement" at the bottom.

> **Live CLI mirror.** `mantle-cli whitelist --json` is the canonical runtime mirror of this file and is the **primary asset-discovery entry point** (SKILL.md §Asset Discovery). The CLI response and this file MUST agree; if they disagree, STOP and surface the discrepancy — this file remains the execution-boundary authority (Hard Constraint #1).

Last aligned: 2026-04-18.

## Asset Whitelist (21 tokens)

### Core Assets

| Symbol | Address (short) | Notes |
|--------|-----------------|-------|
| MNT    | native (no contract) | Native gas token. Use `swap wrap-mnt` / `swap unwrap-mnt` to move between MNT and WMNT. |
| WMNT   | `0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8`   | ERC-20 wrapper for MNT. Required for swap / LP / Aave. |
| USDC   | `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9`   | Bridged USDC. Aave-supported. |
| USDT   | `0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE`   | Bridged Tether. DEX liquidity only — **not** an Aave reserve. |
| USDT0  | `0x779ded0c9e1022225f8e0630b35a9b54be713736`   | LayerZero OFT Tether. **Only USDT variant supported by Aave V3.** |
| WETH   | `0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111`   | Bridged ETH from L1. Deep DEX liquidity. |
| USDe   | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34`   | Ethena USDe. Aave-supported. |
| MOE    | `0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9`   | Merchant Moe governance/utility token. |
| cmETH  | `0xE6829d9a7eE3040e1276Fa75293Bde931859e8fA`   | Restaked mETH (the only whitelisted ETH-family derivative besides WETH). |
| FBTC   | `0xc96de26018a54d51c097160568752c4e3bd6c364`   | The only whitelisted BTC wrap on Mantle. LTV=0 (informational-only collateral on Aave). |

### xStocks Synthetic Assets (8)

Fluxion-only, paired with USDC, `fee_tier=3000`. Not on Aave. CLI symbol = `w<TICKER>x` (with leading `w`, trailing `x`).

| Symbol  | Address (short) |
|---------|-----------------|
| METAx  | `0x96702BE57Cd9777f835117a809c7124fE4ec989a` |
| TSLAx  | `0x8aD3C73f833D3F9a523aB01476625f269AeB7cF0` |
| GOOGLx | `0xe92F673Ca36C5e2efD2DE7628f815f84807E803F` |
| NVDAx  | `0xC845b2894DBDdd03858fd2d643b4eF725FE0849d` |
| QQQx   | `0xa753a7395CAe905CD615dA0b82A53e0560F250AF` |
| AAPLx  | `0x9d275685dc284C8eB1c79F6ABa7A63Dc75EC890a` |
| SPYx   | `0x90A2a4C76b5d8c0Bc892A69eA28aA775a8f2Dd48` |
| MSTRx  | `0xAe2F842Ef90C0d5213259Ab82639d5BBF649b08e` |

| Symbol  | Address (short) |
|---------|-----------------|
| wMETAx  | `0x4E41a262cAA93C6575d336E0a4eb79f3c67caa06` |
| wTSLAx  | `0x43680aBF18cf54898Be84C6eF78237CFBD441883` |
| wGOOGLx | `0x1630F08370917E79df0B7572395a5e907508bBBc` |
| wNVDAx  | `0x93E62845C1DD5822EbC807ab71A5Fb750DecD15A` |
| wQQQx   | `0xdbD9232fee15351068Fe02F0683146e16D9f2cEa` |
| wAAPLx  | `0x5AA7649fdbDa47De64A07aC81D64B682AF9C0724` |
| wSPYx   | `0xc88FcD8B874fDb3256E8B55b3decB8c24EAb4c02` |
| wMSTRx  | `0x266E5923F6118F8b340cA5a23AE7f71897361476` |

### Community Tokens (4)

Fluxion-only, typically paired with USDT0. Multi-hop routing via the CLI bridges them through USDT0 automatically.

| Symbol | Address (short) |
|--------|-----------------|
| BSB    | `0xe5c330ADdf7aa9C7838dA836436142c56a15aa95` |
| ELSA   | `0x29cC30f9D113B356Ce408667aa6433589CeCBDcA` |
| VOOI   | `0xd81a4aDea9932a6BDba0bDBc8C5Fd4C78e5A09f1` |
| SCOR   | `0x8DDB986b11c039a6CC1dbcabd62baE911b348F33` |

## Protocol Whitelist

Only these protocol contracts may appear in an `unsigned_tx.to`, a `--spender` for `approve`, or as a `router` / `position_manager` in a plan. Any other contract address MUST be rejected and the plan stopped.

### Merchant Moe

| Role             | Address (short) |
|------------------|-----------------|
| MoeRouter        | `0xeaee7ee68874218c3558b40063c42b82d3e7232a` |
| LB Router V2.2   | `0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a` |
| LFJ Aggregator   | `0x45a62b090df48243f12a21897e7ed91863e2c86b` |
| LB Factory       | `0xa6630671775c4ea2743840f9a5016dcf2a104054` |
| MoeFactory       | `0x5bef015ca9424a7c07b68490616a4c1f094bedec` |
| MasterChef       | `0xd4bd5e47548d8a6ba2a0bf4ce073cbf8fa523dcc` |
| MoeStaking       | `0xe92249760e1443fbbea45b03f607ba84471fa793` |

### Agni Finance

| Role            | Address (short) |
|-----------------|-----------------|
| SwapRouter      | `0x319B69888b0d11cec22caA5034e25FfFBDc88421` |
| PositionManager | `0x218bf598D1453383e2F4AA7b14fFB9BfB102D637` |
| AgniFactory     | `0x25780dc8fc3cfbd75f33bfdab65e969b603b2035` |
| SmartRouter     | `0xb52b1f5e08c04a8c33f4c7363fa2de23b9bc169f` |

### Fluxion

| Role               | Address (short) |
|--------------------|-----------------|
| V3 SwapRouter      | `0x5628a59df0ecac3f3171f877a94beb26ba6dfaa0` |
| V3 PositionManager | `0x2b70c4e7ca8e920435a5db191e066e9e3afd8db3` |
| V3 Factory         | `0xf883162ed9c7e8ef604214c964c678e40c9b737c` |
| V2 Router          | `0xd772e655af24fe5af92504d613d1da0d9cfb6408` |
| V2 PoolFactory     | `0x9336b143c572d75f1f2b7374532e8c96eed41fe9` |

### Aave V3

| Role         | Address (short) |
|--------------|-----------------|
| Pool         | `0x458F293454fE0d67EC0655f3672301301DD51422` |
| WETHGateway  | `0x9c6ccac66b1c9aba4855e2dd284b9e16e41e06ea` |
| DataProvider | `0x487c5c669D9eee6057C44973207101276cf73b68` |

### WMNT

| Role        | Address (short) |
|-------------|-----------------|
| Wrap/Unwrap | `0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8` |

## Assets / protocols that are NOT on the whitelist (explicitly rejected)

These may appear in natural-language requests, CLI responses, or prior knowledge but are **not** on the canonical list. Treat any request that requires one of them as out-of-scope and refuse:

- Tokens: `mETH`, `sUSDe`, `syrupUSDT`, `wrsETH`, `GHO`, `wHOODx`, `wCRCLx`, `WBTC`, `solvBTC`, `renBTC`, `stETH`, `wstETH`, `rETH`, and any unwrapped US-equity ticker.
- Protocols / routers: any DEX, lending market, bridge, or aggregator not listed above — including alternative RWA venues, non-Mantle-deployed forks, and external aggregators.

## Enforcement (MANDATORY, Hard Constraint #10)

1. **Pre-flight check.** Before the first CLI call that touches an asset or a protocol contract, verify every token symbol and every `--spender` / `--provider` / `to` address against this file. If any item is missing from the whitelist, **STOP**, tell the user which item was rejected, and do not proceed — even if the user insists, accepts risk, or asks you to "just try".
2. **No silent substitution.** Never swap a non-whitelist asset for a similar whitelist one without explicit user confirmation (e.g. user says "stETH"; you must refuse and cite the whitelist — do NOT quietly quote cmETH instead).
3. **No discovery handoff.** Asset Discovery responses must also respect the whitelist — do not surface non-whitelist venues or tokens as "also viable" or "further exploration".
4. **Registry key takes precedence.** `mantle-cli whitelist --json` is the live mirror and the preferred discovery entry point — it should agree with this file. Other CLI surfaces (`mantle-cli catalog`, `mantle-cli swap pairs`, `mantle-cli aave markets`) may include informational tokens. If any CLI response returns a symbol not on this list, treat it as incomplete evidence and still refuse; if `mantle-cli whitelist --json` itself returns an entry not in this file (or vice versa), STOP and surface the discrepancy — do NOT auto-reconcile. The whitelist here governs execution.
5. **Report back.** When refusing, state the exact failing item and the closest whitelist alternative from the same category (e.g. refused `mETH` → closest whitelist alternative `cmETH` or `WETH`). Let the user decide — never auto-pick.
